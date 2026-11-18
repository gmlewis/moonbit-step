///|
// Back-cone-ended straight bevel tooth body.
//
// The large end is split into a flat annular backing plane inside the root
// circle and the conical tooth ends outside it. The tooth caps are triangle
// strips between each tooth's outer boundary and the root circle under it. The
// side surfaces are planar quads because every back/front pair lies on a ray
// from the pitch apex. The bore is an analytic cylinder between the two flat
// faces, so both cap holes are exact circles.

///|
fn compile_bevel_gear_body(
  ctx : StepContext,
  node : SceneNode,
  e : BevelGearBody,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let n = e.back.length()
  if n < 3 ||
    e.front.length() != n ||
    e.teeth.is_empty() ||
    e.front_z_mm <= e.root_z_mm {
    return []
  }

  // Local points: back profile, front profile, then the interior root-arc
  // points generated below.
  let local_pts : Array[Vec3] = []
  local_pts.push_iter(e.back.iter())
  local_pts.push_iter(e.front.iter())
  let (first_start, _) = e.teeth[0]
  let root_radius = Double::sqrt(
    e.back[first_start].0 * e.back[first_start].0 +
    e.back[first_start].1 * e.back[first_start].1,
  )
  if !(root_radius > e.bore_radius_mm) {
    return []
  }

  // Generate the under-tooth root-circle arcs. The endpoints reuse the back
  // profile's root points so the backing and lobe faces share those edges.
  let two_pi = 2.0 * @math.PI
  let arcs : Array[Array[Int32]] = []
  for tooth in e.teeth {
    let (start, end) = tooth
    if start < 0 || end >= n || end <= start {
      return []
    }
    let count = end - start + 1
    let a0 = @math.atan2(e.back[start].1, e.back[start].0)
    let a1 = @math.atan2(e.back[end].1, e.back[end].0)
    let raw = a1 - a0
    let mut delta = raw - two_pi * Double::floor(raw / two_pi)
    if delta <= 1.0e-12 {
      delta = delta + two_pi
    }
    let arc : Array[Int32] = [start]
    for i in 1..<(count - 1) {
      let ang = a0 + delta * i.to_double() / (count - 1).to_double()
      let idx = local_pts.length()
      local_pts.push(
        (
          root_radius * @math.cos(ang),
          root_radius * @math.sin(ang),
          e.root_z_mm,
        ),
      )
      arc.push(idx)
    }
    arc.push(end)
    arcs.push(arc)
  }

  // Backing loop: each tooth's root arc followed by the gap root points up to
  // the next tooth's start.
  let backing : Array[Int32] = []
  let num_teeth = e.teeth.length()
  for k in 0..<num_teeth {
    let arc = arcs[k]
    backing.push_iter(arc.iter())
    let end = e.teeth[k].1
    let next_start = e.teeth[(k + 1) % num_teeth].0
    let mut idx = (end + 1) % n
    while idx != next_start {
      backing.push(idx)
      idx = (idx + 1) % n
    }
  }

  let pts = local_pts.map(fn(p) { xform.apply(p) })
  let cp_refs = pts.map(fn(p) {
    let (px, py, pz) = p
    ctx.cartesian_point(px, py, pz)
  })
  let vp_refs = cp_refs.map(fn(cp) { ctx.vertex_point(cp) })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map([])
  let add_edge = fn(a : Int32, b : Int32) -> Unit {
    if a == b {
      return
    }
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

  let front_offset = n
  for i in 0..<n {
    let j = (i + 1) % n
    add_edge(i, j)
    add_edge(front_offset + i, front_offset + j)
    add_edge(i, front_offset + i)
  }
  for arc in arcs {
    let m = arc.length()
    for i in 0..<(m - 1) {
      add_edge(arc[i], arc[i + 1])
    }
  }

  let face_refs : Array[@step.Ref] = []

  // Side surfaces: planar quads between corresponding back and front points.
  // Split each quad along its diagonal into two triangles so a skinny root-land
  // quad cannot trip the four-point planarity test.
  for i in 0..<n {
    let j = (i + 1) % n
    let p0 = pts[i]
    let p1 = pts[j]
    let p2 = pts[front_offset + i]
    let p3 = pts[front_offset + j]
    add_edge(i, front_offset + j)
    let expected1 = v_norm(v_cross(v_sub(p1, p0), v_sub(p3, p0)))
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [i, j, front_offset + j],
        expected1,
        reverse~,
      ),
    )
    let expected2 = v_norm(v_cross(v_sub(p3, p0), v_sub(p2, p0)))
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [i, front_offset + j, front_offset + i],
        expected2,
        reverse~,
      ),
    )
  }

  // Conical tooth caps: strips between each tooth boundary and its root arc.
  for k in 0..<num_teeth {
    let (start, end) = e.teeth[k]
    let arc = arcs[k]
    let count = end - start + 1
    for i in 0..<(count - 1) {
      let b0 = start + i
      let b1 = start + i + 1
      let r0 = arc[i]
      let r1 = arc[i + 1]
      for tri in [[b0, b1, r1], [b0, r1, r0]] {
        let (i0, i1, i2) = (tri[0], tri[1], tri[2])
        if i0 == i1 || i1 == i2 || i2 == i0 {
          continue
        }
        // Triangle area test (skip a degenerate strip at the root corners).
        let pa = pts[i0]
        let pb = pts[i1]
        let pc = pts[i2]
        let area_vec = v_cross(v_sub(pb, pa), v_sub(pc, pa))
        if v_dot(area_vec, area_vec) <= 1.0e-24 {
          continue
        }
        add_edge(i0, i1)
        add_edge(i1, i2)
        add_edge(i2, i0)
        let la = local_pts[i0]
        let lb = local_pts[i1]
        let lc = local_pts[i2]
        let cx = (la.0 + lb.0 + lc.0) / 3.0
        let cy = (la.1 + lb.1 + lc.1) / 3.0
        let rr = Double::sqrt(cx * cx + cy * cy)
        let expected = if rr > 1.0e-9 {
          xform.apply_dir((cx / rr, cy / rr, -e.cone_tan_half_angle))
        } else {
          xform.apply_dir((0.0, 0.0, -1.0))
        }
        face_refs.push(
          add_plane_face_oriented(
            ctx,
            edges,
            pts,
            cp_refs,
            [i0, i1, i2],
            expected,
            reverse~,
          ),
        )
      }
    }
  }

  // Bore: analytic cylinder between the backing plane and the front plane.
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let root_cycle : Array[Int32] = backing.copy()
  let front_cycle : Array[Int32] = []
  for i in 0..<n {
    front_cycle.push(front_offset + i)
  }
  if e.bore_radius_mm > 0.0 {
    let right = xform.apply_dir((1.0, 0.0, 0.0))
    let dir_up = ctx.direction(up.0, up.1, up.2)
    let dir_right = ctx.direction(right.0, right.1, right.2)
    let p_b = xform.apply((0.0, 0.0, e.root_z_mm))
    let p_t = xform.apply((0.0, 0.0, e.front_z_mm))
    let cp_b = ctx.cartesian_point(p_b.0, p_b.1, p_b.2)
    let cp_t = ctx.cartesian_point(p_t.0, p_t.1, p_t.2)
    let a2p_b = ctx.axis2_placement_3d(cp_b, dir_up, dir_right)
    let a2p_t = ctx.axis2_placement_3d(cp_t, dir_up, dir_right)
    let radius = @step.fmt_num(e.bore_radius_mm)
    let circle_b = ctx.add(
      @repository.any_entity_circle(@geometry.Circle::new("", a2p_b, radius)),
    )
    let circle_t = ctx.add(
      @repository.any_entity_circle(@geometry.Circle::new("", a2p_t, radius)),
    )
    let cylinder = ctx.add(
      @repository.any_entity_cylindrical_surface(
        @geometry.CylindricalSurface::new("", a2p_b, radius),
      ),
    )
    let seam_b = xform.apply((e.bore_radius_mm, 0.0, e.root_z_mm))
    let seam_t = xform.apply((e.bore_radius_mm, 0.0, e.front_z_mm))
    let cp_sb = ctx.cartesian_point(seam_b.0, seam_b.1, seam_b.2)
    let cp_st = ctx.cartesian_point(seam_t.0, seam_t.1, seam_t.2)
    let vp_sb = ctx.vertex_point(cp_sb)
    let vp_st = ctx.vertex_point(cp_st)
    let seam = ctx.edge_curve(
      vp_sb,
      vp_st,
      ctx.line(cp_sb, ctx.vector(dir_up, 1.0)),
      true,
    )
    let e_b = ctx.edge_curve(vp_sb, vp_sb, circle_b, true)
    let e_t = ctx.edge_curve(vp_st, vp_st, circle_t, true)
    let lateral_loop = ctx.edge_loop([
      ctx.oriented_edge(seam, true),
      ctx.oriented_edge(e_t, true),
      ctx.oriented_edge(seam, false),
      ctx.oriented_edge(e_b, false),
    ])
    face_refs.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(lateral_loop, true)],
        cylinder,
        reverse,
      ),
    )
    let root_hole = ctx.edge_loop([ctx.oriented_edge(e_b, true)])
    let front_hole = ctx.edge_loop([ctx.oriented_edge(e_t, false)])
    face_refs.push(
      add_plane_face_with_edge_loops(
        ctx,
        edges,
        pts,
        cp_refs,
        root_cycle,
        [root_hole],
        down,
        reverse~,
      ),
    )
    face_refs.push(
      add_plane_face_with_edge_loops(
        ctx,
        edges,
        pts,
        cp_refs,
        front_cycle,
        [front_hole],
        up,
        reverse~,
      ),
    )
  } else {
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        root_cycle,
        [],
        down,
        reverse~,
      ),
    )
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        front_cycle,
        [],
        up,
        reverse~,
      ),
    )
  }
  face_refs
}
