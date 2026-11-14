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
