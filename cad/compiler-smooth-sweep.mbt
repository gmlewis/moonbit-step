///|
// Native smooth B-rep for a general polygonal profile swept along a path.
//
// Every profile edge becomes one ruled B-spline surface: degree 1 across the
// edge (between the two vertex curves) and cubic along the path, with one
// cubic Bezier span per sampled path point. Adjacent surfaces share their
// vertex curve edges, and the start/end caps are planar faces built from the
// profile polygon, so the shell stays watertight. A loop that keeps the
// orientation of the first path point (straight_holes / straight_outline)
// produces straight vertex curves, so its side surfaces are exact planes.

///|
/// smooth_sweep_curve builds the B-spline curve traced by one profile vertex
/// along the whole path. One cubic Bezier span connects every pair of
/// consecutive path points, so the surface interpolates every sampled
/// cross-section exactly.
fn smooth_sweep_curve(
  ctx : StepContext,
  pts : Array[Vec3],
  num_path_pts : Int32,
  num_prof_verts : Int32,
  profile_index : Int32,
  v_mults : Array[Int32],
  v_knots : Array[String],
  sharp_creases : Array[Int32],
) -> SmoothCurve {
  let indices : Array[Int32] = Array::make(num_path_pts, 0)
  for i in 0..<num_path_pts {
    indices[i] = i
  }
  smooth_curve(
    ctx,
    pts,
    indices,
    profile_index,
    num_path_pts,
    v_mults,
    v_knots,
    stride=num_prof_verts,
    sharp_creases~,
  )
}

///|
/// periodic_catmull_bezier_cps builds `3 * n + 1` cubic Bezier control points
/// around a closed loop of `n` points `loop_pts` using periodic Catmull-Rom
/// tangents so index `0` and index `3 * n` coincide at `loop_pts[0]` with C1
/// continuity across the seam.
fn periodic_catmull_bezier_cps(loop_pts : Array[Vec3]) -> Array[Vec3] {
  let n = loop_pts.length()
  let cps : Array[Vec3] = []
  for j in 0..<n {
    let p_prev = loop_pts[(j + n - 1) % n]
    let p0 = loop_pts[j]
    let p3 = loop_pts[(j + 1) % n]
    let p_next = loop_pts[(j + 2) % n]
    let t0 = v_scale(v_sub(p3, p_prev), 0.5)
    let t1 = v_scale(v_sub(p_next, p0), 0.5)
    let q1 = v_add(p0, v_scale(t0, 1.0 / 3.0))
    let q2 = v_sub(p3, v_scale(t1, 1.0 / 3.0))
    if j == 0 {
      cps.push(p0)
    }
    cps.push(q1)
    cps.push(q2)
    cps.push(p3)
  }
  cps
}

///|
/// clamped_catmull_bezier_cps builds `3 * (n - 1) + 1` cubic Bezier control
/// points along an open chain of `n` points with optional sharp creases.
fn clamped_catmull_bezier_cps(
  pts : Array[Vec3],
  sharp_creases : Array[Int32],
) -> Array[Vec3] {
  let n = pts.length()
  let is_crease = fn(idx : Int32) -> Bool {
    for c in sharp_creases {
      if c == idx {
        return true
      }
    }
    false
  }
  let cps : Array[Vec3] = []
  for k in 0..<(n - 1) {
    let p0 = pts[k]
    let p3 = pts[k + 1]
    let t_start = if is_crease(k) {
      v_sub(p3, p0)
    } else if k == 0 {
      v_sub(pts[1], pts[0])
    } else {
      v_scale(v_sub(pts[k + 1], pts[k - 1]), 0.5)
    }
    let t_end = if is_crease(k + 1) {
      v_sub(p3, p0)
    } else if k + 1 == n - 1 {
      v_sub(pts[n - 1], pts[n - 2])
    } else {
      v_scale(v_sub(pts[k + 2], pts[k]), 0.5)
    }
    let q1 = v_add(p0, v_scale(t_start, 1.0 / 3.0))
    let q2 = v_sub(p3, v_scale(t_end, 1.0 / 3.0))
    if k == 0 {
      cps.push(p0)
    }
    cps.push(q1)
    cps.push(q2)
    cps.push(p3)
  }
  cps
}

///|
fn sweep_orthogonal_dir(n : Vec3) -> Vec3 {
  let c = if Double::abs(n.0) < 0.9 { (1.0, 0.0, 0.0) } else { (0.0, 1.0, 0.0) }
  v_norm(v_cross(n, c))
}

///|
/// compile_smooth_closed_swept_profile emits one seamless degree-(3, 3) closed
/// B-spline tube surface per profile loop and planar spline caps.
fn compile_smooth_closed_swept_profile(
  ctx : StepContext,
  xform : Transform,
  s : SweptProfile,
  pts : Array[Vec3],
  local_loops : Array[Array[Vec3]],
  loop_offsets : Array[Int32],
  num_path_pts : Int32,
  num_prof_verts : Int32,
  reverse : Bool,
) -> Array[@step.Ref] {
  let num_loops = local_loops.length()
  let num_v_spans = num_path_pts - 1
  let v_mults : Array[Int32] = [4]
  for _ in 1..<num_v_spans {
    v_mults.push(3)
  }
  v_mults.push(4)
  let v_knots : Array[String] = []
  for i in 0..<=num_v_spans {
    v_knots.push(@step.fmt_num(i.to_double()))
  }
  let v_mults_text = "(" + v_mults.map(fn(m) { "\{m}" }).join(",") + ")"
  let v_knots_text = "(" + v_knots.join(",") + ")"

  let start_edges : Array[@step.Ref] = []
  let end_edges : Array[@step.Ref] = []
  let face_refs : Array[@step.Ref] = []
  let t0_world = v_norm(xform.apply_dir(s.path.tangents[0]))
  let last = num_path_pts - 1

  for li in 0..<num_loops {
    let lo = loop_offsets[li]
    let n = local_loops[li].length()
    // Orient loop around start tangent so (du x dv) always points outward:
    // outer loop CCW around +t0 (+dot > 0), holes CW around +t0 (dot < 0).
    let raw_start : Array[Vec3] = []
    for j in 0..<n {
      raw_start.push(pts[lo + j])
    }
    let poly_norm = smooth_polygon_normal(raw_start)
    let want_pos = li == 0
    let need_rev = if want_pos {
      v_dot(poly_norm, t0_world) < 0.0
    } else {
      v_dot(poly_norm, t0_world) > 0.0
    }

    // U cubic Bezier CPs across each sampled cross section i.
    let u_rows : Array[Array[Vec3]] = []
    for i in 0..<num_path_pts {
      let row_pts : Array[Vec3] = []
      for j in 0..<n {
        let idx = if need_rev { n - 1 - j } else { j }
        row_pts.push(pts[i * num_prof_verts + lo + idx])
      }
      u_rows.push(periodic_catmull_bezier_cps(row_pts))
    }
    let num_u_cps = u_rows[0].length() // 3 * n + 1

    // V cubic Bezier CPs along each U control column u_col = 0 ..< num_u_cps.
    let grid_cps : Array[Array[@step.Ref]] = []
    let seam_cps_vec : Array[Vec3] = []
    for u_col in 0..<num_u_cps {
      let col_in : Array[Vec3] = []
      for i in 0..<num_path_pts {
        col_in.push(u_rows[i][u_col])
      }
      let col_cps = clamped_catmull_bezier_cps(col_in, s.sharp_creases)
      if u_col == 0 {
        for p in col_cps {
          seam_cps_vec.push(p)
        }
      }
      grid_cps.push(col_cps.map(fn(p) { ctx.cartesian_point(p.0, p.1, p.2) }))
    }

    let u_mults : Array[Int32] = [4]
    for _ in 1..<n {
      u_mults.push(3)
    }
    u_mults.push(4)
    let u_knots : Array[String] = []
    for j in 0..<=n {
      u_knots.push(@step.fmt_num(j.to_double()))
    }
    let u_mults_text = "(" + u_mults.map(fn(m) { "\{m}" }).join(",") + ")"
    let u_knots_text = "(" + u_knots.join(",") + ")"

    let rows_text = "(" +
      grid_cps
      .map(fn(row) { "(" + row.map(fn(r) { "#\{r.id.value}" }).join(",") + ")" })
      .join(",") +
      ")"
    let surf_args = "('',3,3," +
      rows_text +
      ",.UNSPECIFIED.,.F.,.F.,.F.," +
      u_mults_text +
      "," +
      v_mults_text +
      "," +
      u_knots_text +
      "," +
      v_knots_text +
      ",.PIECEWISE_BEZIER_KNOTS.)"
    let surf_ref = ctx.add(
      @repository.any_entity_raw_entity(
        @step.RawEntity::new("B_SPLINE_SURFACE_WITH_KNOTS", surf_args),
      ),
    )

    let vp_start = ctx.vertex_point(grid_cps[0][0])
    let vp_end = ctx.vertex_point(grid_cps[0][grid_cps[0].length() - 1])
    let seam_curve_ref = ctx.add(
      @repository.any_entity_b_spline_curve_with_knots(
        @geometry.BSplineCurveWithKnots::new(
          "",
          3,
          grid_cps[0],
          ".UNSPECIFIED.",
          false,
          false,
          v_mults,
          v_knots,
          ".PIECEWISE_BEZIER_KNOTS.",
        ),
      ),
    )
    let seam_edge = ctx.edge_curve(vp_start, vp_end, seam_curve_ref, true)

    let start_cp_refs = grid_cps.map(fn(row) { row[0] })
    let start_curve_ref = ctx.add(
      @repository.any_entity_b_spline_curve_with_knots(
        @geometry.BSplineCurveWithKnots::new(
          "", 3, start_cp_refs, ".UNSPECIFIED.", false, false, u_mults, u_knots,
          ".PIECEWISE_BEZIER_KNOTS.",
        ),
      ),
    )
    let start_edge = ctx.edge_curve(vp_start, vp_start, start_curve_ref, true)

    let end_cp_refs = grid_cps.map(fn(row) { row[row.length() - 1] })
    let end_curve_ref = ctx.add(
      @repository.any_entity_b_spline_curve_with_knots(
        @geometry.BSplineCurveWithKnots::new(
          "", 3, end_cp_refs, ".UNSPECIFIED.", false, false, u_mults, u_knots, ".PIECEWISE_BEZIER_KNOTS.",
        ),
      ),
    )
    let end_edge = ctx.edge_curve(vp_end, vp_end, end_curve_ref, true)
    start_edges.push(start_edge)
    end_edges.push(end_edge)

    let _ = seam_cps_vec
    let loop_ref = ctx.edge_loop([
      ctx.oriented_edge(start_edge, true),
      ctx.oriented_edge(seam_edge, true),
      ctx.oriented_edge(end_edge, false),
      ctx.oriented_edge(seam_edge, false),
    ])
    let bound = ctx.face_outer_bound(loop_ref, true)
    face_refs.push(ctx.advanced_face([bound], surf_ref, !reverse))
  }

  let emit_cap = fn(
    base_pt : Vec3,
    out_dir_local : Vec3,
    cap_edges : Array[@step.Ref],
    outer_sense : Bool,
    hole_sense : Bool,
  ) {
    let normal = v_norm(xform.apply_dir(out_dir_local))
    let ref_d = sweep_orthogonal_dir(normal)
    let a2p = ctx.axis2_placement_3d(
      ctx.cartesian_point(base_pt.0, base_pt.1, base_pt.2),
      ctx.direction(normal.0, normal.1, normal.2),
      ctx.direction(ref_d.0, ref_d.1, ref_d.2),
    )
    let plane = ctx.add(
      @repository.any_entity_plane(@geometry.Plane::new("", a2p)),
    )
    let bounds : Array[@step.Ref] = [
      ctx.face_outer_bound(
        ctx.edge_loop([ctx.oriented_edge(cap_edges[0], outer_sense)]),
        true,
      ),
    ]
    for li in 1..<num_loops {
      bounds.push(
        ctx.face_bound(
          ctx.edge_loop([ctx.oriented_edge(cap_edges[li], hole_sense)]),
          true,
        ),
      )
    }
    face_refs.push(ctx.advanced_face(bounds, plane, !reverse))
  }

  if s.make_start_cap {
    let t0 = s.path.tangents[0]
    emit_cap(pts[0], (-t0.0, -t0.1, -t0.2), start_edges, false, false)
  }
  if s.make_end_cap {
    let t1 = s.path.tangents[last]
    emit_cap(
      pts[last * num_prof_verts],
      (t1.0, t1.1, t1.2),
      end_edges,
      true,
      true,
    )
  }
  face_refs
}

///|
/// compile_smooth_swept_profile emits the sweep as smooth B-spline side
/// surfaces and planar caps instead of planar facets.
fn compile_smooth_swept_profile(
  ctx : StepContext,
  node : SceneNode,
  s : SweptProfile,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let path = s.path
  let profile = s.profile
  let num_path_pts = path.points.length()
  if num_path_pts < 2 || profile.vertices.length() < 3 {
    return []
  }

  // Profile loops: outer boundary first, then any holes.
  let loops : Array[Array[Vec3]] = [
    profile.vertices,
    ..profile.holes.filter(fn(h) { h.length() >= 3 }),
  ]
  let num_loops = loops.length()

  // Profile-local coordinates (the same mapping the faceted sweep uses).
  let prof_z = v_norm(profile.normal_dir)
  let prof_x = v_norm(profile.right_dir)
  let prof_y = v_norm(v_cross(prof_z, prof_x))
  let m_global_to_prof = Matrix3x3::{
    m00: prof_x.0,
    m01: prof_x.1,
    m02: prof_x.2,
    m10: prof_y.0,
    m11: prof_y.1,
    m12: prof_y.2,
    m20: prof_z.0,
    m21: prof_z.1,
    m22: prof_z.2,
  }
  let local_loops = loops.map(fn(lp) {
    lp.map(fn(v) { apply_matrix(m_global_to_prof, v_sub(v, profile.center)) })
  })
  let loop_offsets : Array[Int32] = []
  let local_verts : Array[Vec3] = []
  let is_hole : Array[Bool] = []
  let mut loop_index = 0
  for lp in local_loops {
    loop_offsets.push(local_verts.length())
    for v in lp {
      local_verts.push(v)
      is_hole.push(loop_index > 0)
    }
    loop_index = loop_index + 1
  }
  let num_prof_verts = local_verts.length()

  // Holes and/or the outer boundary can optionally stay parallel to the sweep
  // axis instead of rotating with the path frame.
  let t0 = v_norm(path.tangents[0])
  let n0 = v_norm(path.normals[0])
  let r0 = v_norm(v_cross(t0, n0))

  // World positions of every profile vertex at every path point.
  let pts : Array[Vec3] = []
  for i in 0..<num_path_pts {
    let p_origin = path.points[i]
    let p_tangent = v_norm(path.tangents[i])
    let p_normal = v_norm(path.normals[i])
    let p_right = v_norm(v_cross(p_tangent, p_normal))
    let m_path_to_global = Matrix3x3::{
      m00: p_right.0,
      m01: p_normal.0,
      m02: p_tangent.0,
      m10: p_right.1,
      m11: p_normal.1,
      m12: p_tangent.1,
      m20: p_right.2,
      m21: p_normal.2,
      m22: p_tangent.2,
    }
    let m_start_to_global = Matrix3x3::{
      m00: r0.0,
      m01: n0.0,
      m02: t0.0,
      m10: r0.1,
      m11: n0.1,
      m12: t0.1,
      m20: r0.2,
      m21: n0.2,
      m22: t0.2,
    }
    for j, v in local_verts {
      let keep_straight = if is_hole[j] {
        s.straight_holes
      } else {
        s.straight_outline
      }
      let gv = if keep_straight {
        apply_matrix(m_start_to_global, v)
      } else {
        apply_matrix(m_path_to_global, v)
      }
      pts.push(
        xform.apply((gv.0 + p_origin.0, gv.1 + p_origin.1, gv.2 + p_origin.2)),
      )
    }
  }

  if s.smooth_profile {
    return compile_smooth_closed_swept_profile(
      ctx, xform, s, pts, local_loops, loop_offsets, num_path_pts, num_prof_verts,
      reverse,
    )
  }

  // Vertices and the straight cross-section edges at the two caps.
  let cp_refs = pts.map(fn(pt) { ctx.cartesian_point(pt.0, pt.1, pt.2) })
  let vp_refs = cp_refs.map(fn(cp_ref) { ctx.vertex_point(cp_ref) })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map([])
  let add_edge = fn(a : Int32, b : Int32) -> Unit {
    let key = if a < b { "\{a}:\{b}" } else { "\{b}:\{a}" }
    if seen.get(key).unwrap_or(false) {
      return
    }
    seen.set(key, true)
    let start = if a < b { a } else { b }
    let end = if a < b { b } else { a }
    let dir_raw = v_norm(v_sub(pts[end], pts[start]))
    let dir_ref = ctx.direction(dir_raw.0, dir_raw.1, dir_raw.2)
    let vec_ref = ctx.vector(dir_ref, 1.0)
    let line_ref = ctx.line(cp_refs[start], vec_ref)
    let ec_ref = ctx.edge_curve(vp_refs[start], vp_refs[end], line_ref, true)
    edges.push(EdgeInfo::{ start, end, edge: ec_ref, })
  }

  let last = num_path_pts - 1
  let offset_last = last * num_prof_verts
  for base in [0, offset_last] {
    for li in 0..<num_loops {
      let lo = loop_offsets[li]
      let n = local_loops[li].length()
      for j in 0..<n {
        let k = (j + 1) % n
        add_edge(base + lo + j, base + lo + k)
      }
    }
  }

  // One cubic Bezier span per sampled path point, clamped at both ends.
  let num_spans = num_path_pts - 1
  let v_mults : Array[Int32] = [4]
  for _ in 1..<num_spans {
    v_mults.push(3)
  }
  v_mults.push(4)
  let v_knots : Array[String] = []
  for i in 0..<=num_spans {
    v_knots.push(@step.fmt_num(i.to_double()))
  }

  let curves : Array[SmoothCurve] = []
  for j in 0..<num_prof_verts {
    curves.push(
      smooth_sweep_curve(
        ctx,
        pts,
        num_path_pts,
        num_prof_verts,
        j,
        v_mults,
        v_knots,
        s.sharp_creases,
      ),
    )
  }

  let curve_edges = curves.map(fn(c) {
    ctx.edge_curve(
      ctx.vertex_point(c.start_cp),
      ctx.vertex_point(c.end_cp),
      c.curve_ref,
      true,
    )
  })

  // One ruled B-spline side surface per profile edge.
  let face_refs : Array[@step.Ref] = []
  for li in 0..<num_loops {
    let lo = loop_offsets[li]
    let n = local_loops[li].length()
    for j in 0..<n {
      let k = (j + 1) % n
      let bj = lo + j
      let bk = lo + k
      let cj = curves[bj]
      let ck = curves[bk]
      let p0 = pts[bj]
      let p1 = pts[bk]
      let p2 = pts[num_prof_verts + bj]
      let expected = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
      let (surface, _same) = smooth_surface(
        ctx, cj, ck, expected, v_mults, v_knots,
      )
      // `smooth_face` reverses the cycle it is handed, so hand it the
      // clockwise (u, v) cycle; the emitted loop then winds counterclockwise
      // around the surface normal, matching `same_sense = true`.
      let (end_cross, end_ori) = find_edge(
        edges,
        offset_last + bj,
        offset_last + bk,
      )
      let (start_cross, start_ori) = find_edge(edges, bk, bj)
      face_refs.push(
        smooth_face(
          ctx,
          [
            (curve_edges[bj], true),
            (end_cross, end_ori),
            (curve_edges[bk], false),
            (start_cross, start_ori),
          ],
          surface,
          !reverse,
        ),
      )
    }
  }

  // Build the vertex cycle of loop `li` at path point `base`.
  let loop_cycle = fn(base : Int32, li : Int32) -> Array[Int32] {
    let lo = loop_offsets[li]
    let n = local_loops[li].length()
    let cycle = Array::make(n, 0)
    for j in 0..<n {
      cycle[j] = base + lo + j
    }
    cycle
  }

  if s.make_start_cap {
    let tangent = path.tangents[0]
    let (tx, ty, tz) = xform.apply_dir(tangent)
    let expected_out = (-tx, -ty, -tz)
    let hole_cycles : Array[Array[Int32]] = []
    for li in 1..<num_loops {
      hole_cycles.push(loop_cycle(0, li))
    }
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        loop_cycle(0, 0),
        hole_cycles,
        expected_out,
        reverse~,
      ),
    )
  }

  if s.make_end_cap {
    let tangent = path.tangents[last]
    let (tx, ty, tz) = xform.apply_dir(tangent)
    let expected_out = (tx, ty, tz)
    let hole_cycles : Array[Array[Int32]] = []
    for li in 1..<num_loops {
      hole_cycles.push(loop_cycle(offset_last, li))
    }
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        loop_cycle(offset_last, 0),
        hole_cycles,
        expected_out,
        reverse~,
      ),
    )
  }
  face_refs
}
