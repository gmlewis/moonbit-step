///|
fn v_sub(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> (Double, Double, Double) {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ax - bx, ay - by, az - bz)
}

///|
fn v_cross(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> (Double, Double, Double) {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
}

///|
fn v_dot(a : (Double, Double, Double), b : (Double, Double, Double)) -> Double {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  ax * bx + ay * by + az * bz
}

///|
fn v_len(a : (Double, Double, Double)) -> Double {
  let (x, y, z) = a
  Double::sqrt(x * x + y * y + z * z)
}

///|
fn v_norm(a : (Double, Double, Double)) -> (Double, Double, Double) {
  let l = v_len(a)
  if l == 0.0 {
    (1.0, 0.0, 0.0)
  } else {
    let (x, y, z) = a
    (x / l, y / l, z / l)
  }
}

///|
fn reverse_cycle(verts : Array[Int]) -> Array[Int] {
  verts.rev()
}

///|
fn cycle_area_xy(
  pts : Array[(Double, Double, Double)],
  cycle : Array[Int],
) -> Double {
  let n = cycle.length()
  if n < 3 {
    return 0.0
  }
  let mut a = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    let (xi, yi, _zi) = pts[cycle[i]]
    let (xj, yj, _zj) = pts[cycle[j]]
    a = a + (xi * yj - xj * yi)
  }
  a
}

///|
fn rotate_point(
  p : (Double, Double, Double),
  rx : Double,
  ry : Double,
  rz : Double,
) -> (Double, Double, Double) {
  let rad_x = rx * @math.PI / 180.0
  let rad_y = ry * @math.PI / 180.0
  let rad_z = rz * @math.PI / 180.0

  //
  let (x0, y0, z0) = p
  let mut x = x0
  let mut y = y0
  let mut z = z0

  // Rotate X
  if rx != 0.0 {
    let old_y = y
    let old_z = z
    y = old_y * @math.cos(rad_x) - old_z * @math.sin(rad_x)
    z = old_y * @math.sin(rad_x) + old_z * @math.cos(rad_x)
  }

  // Rotate Y
  if ry != 0.0 {
    let old_x = x
    let old_z = z
    x = old_x * @math.cos(rad_y) + old_z * @math.sin(rad_y)
    z = -old_x * @math.sin(rad_y) + old_z * @math.cos(rad_y)
  }

  // Rotate Z
  if rz != 0.0 {
    let old_x = x
    let old_y = y
    x = old_x * @math.cos(rad_z) - old_y * @math.sin(rad_z)
    y = old_x * @math.sin(rad_z) + old_y * @math.cos(rad_z)
  }

  //
  (x, y, z)
}

///|
pub(all) struct EdgeInfo {
  start : Int
  end : Int
  edge : @step.Ref
}

///|
fn find_edge(edges : Array[EdgeInfo], a : Int, b : Int) -> (@step.Ref, Bool) {
  for e in edges {
    if e.start == a && e.end == b {
      return (e.edge, true)
    }
    if e.start == b && e.end == a {
      return (e.edge, false)
    }
  }
  (edges[0].edge, true)
}

///|
fn face_loop(
  ctx : StepContext,
  edges : Array[EdgeInfo],
  verts : Array[Int],
) -> @step.Ref {
  let oe_refs : Array[@step.Ref] = []
  let n = verts.length()
  for i in 0..<n {
    let a = verts[i]
    let b = verts[(i + 1) % n]
    let (edge_ref, ori) = find_edge(edges, a, b)
    let oe = @topology.OrientedEdge::new("", "*", "*", edge_ref, ori)
    oe_refs.push(ctx.add(@repository.any_entity_oriented_edge(oe)))
  }
  let edge_loop = @topology.EdgeLoop::new("", oe_refs)
  ctx.add(@repository.any_entity_edge_loop(edge_loop))
}

///|
fn add_plane_face(
  ctx : StepContext,
  edges : Array[EdgeInfo],
  verts_cycle : Array[Int],
  location_pt : @step.Ref,
  axis_dir : @step.Ref,
  ref_dir : @step.Ref,
) -> @step.Ref {
  let a2p = @geometry.Axis2Placement3D::new("", location_pt, axis_dir, ref_dir)
  let a2p_ref = ctx.add(@repository.any_entity_axis2_placement_3d(a2p))
  let plane = @geometry.Plane::new("", a2p_ref)
  let plane_ref = ctx.add(@repository.any_entity_plane(plane))
  let loop_ref = face_loop(ctx, edges, verts_cycle)
  let fob = @topology.FaceOuterBound::new("", loop_ref, true)
  let fob_ref = ctx.add(@repository.any_entity_face_outer_bound(fob))
  let face = @topology.AdvancedFace::new("", [fob_ref], plane_ref, true)
  ctx.add(@repository.any_entity_advanced_face(face))
}

///|
fn add_plane_face_oriented(
  ctx : StepContext,
  edges : Array[EdgeInfo],
  pts : Array[(Double, Double, Double)],
  cp_refs : Array[@step.Ref],
  verts_cycle : Array[Int],
  expected_out : (Double, Double, Double),
) -> @step.Ref {
  let a0 = verts_cycle[0]
  let a1 = verts_cycle[1]
  let a2 = verts_cycle[2]
  let p0 = pts[a0]
  let p1 = pts[a1]
  let p2 = pts[a2]
  let n = v_cross(v_sub(p1, p0), v_sub(p2, p0))
  let cycle = if v_dot(n, expected_out) < 0.0 {
    reverse_cycle(verts_cycle)
  } else {
    verts_cycle
  }
  let b0 = cycle[0]
  let axis_raw = v_norm(expected_out)
  let refd_raw = v_norm(v_sub(pts[cycle[1]], pts[cycle[0]]))
  let axis_ref = ctx.direction(axis_raw.0, axis_raw.1, axis_raw.2)
  let ref_ref = ctx.direction(refd_raw.0, refd_raw.1, refd_raw.2)
  add_plane_face(ctx, edges, cycle, cp_refs[b0], axis_ref, ref_ref)
}

///|
fn add_plane_face_with_holes_oriented(
  ctx : StepContext,
  edges : Array[EdgeInfo],
  pts : Array[(Double, Double, Double)],
  cp_refs : Array[@step.Ref],
  outer_cycle_in : Array[Int],
  hole_cycles_in : Array[Array[Int]],
  expected_out : (Double, Double, Double),
) -> @step.Ref {
  let a0 = outer_cycle_in[0]
  let a1 = outer_cycle_in[1]
  let a2 = outer_cycle_in[2]
  let p0 = pts[a0]
  let p1 = pts[a1]
  let p2 = pts[a2]
  let n = v_cross(v_sub(p1, p0), v_sub(p2, p0))
  let outer_cycle = if v_dot(n, expected_out) < 0.0 {
    reverse_cycle(outer_cycle_in)
  } else {
    outer_cycle_in
  }

  //
  let hole_cycles = hole_cycles_in.map(fn(hc) {
    let ha = cycle_area_xy(pts, hc)
    let outer_area = cycle_area_xy(pts, outer_cycle)
    if (outer_area >= 0.0 && ha >= 0.0) || (outer_area < 0.0 && ha < 0.0) {
      reverse_cycle(hc)
    } else {
      hc
    }
  })

  //
  let b0 = outer_cycle[0]
  let axis_raw = v_norm(expected_out)
  let refd_raw = v_norm(v_sub(pts[outer_cycle[1]], pts[outer_cycle[0]]))
  let axis_ref = ctx.direction(axis_raw.0, axis_raw.1, axis_raw.2)
  let ref_ref = ctx.direction(refd_raw.0, refd_raw.1, refd_raw.2)

  //
  let a2p = @geometry.Axis2Placement3D::new("", cp_refs[b0], axis_ref, ref_ref)
  let a2p_ref = ctx.add(@repository.any_entity_axis2_placement_3d(a2p))
  let plane = @geometry.Plane::new("", a2p_ref)
  let plane_ref = ctx.add(@repository.any_entity_plane(plane))

  //
  let outer_loop_ref = face_loop(ctx, edges, outer_cycle)
  let fob = @topology.FaceOuterBound::new("", outer_loop_ref, true)
  let fob_ref = ctx.add(@repository.any_entity_face_outer_bound(fob))

  //
  let bounds : Array[@step.Ref] = [fob_ref]
  bounds.push_iter(
    hole_cycles
    .iter()
    .map(fn(loop_pts) {
      let loop_ref = face_loop(ctx, edges, loop_pts)
      let fb = @topology.FaceBound::new("", loop_ref, true)
      ctx.add(@repository.any_entity_face_bound(fb))
    }),
  )
  let face = @topology.AdvancedFace::new("", bounds, plane_ref, true)
  ctx.add(@repository.any_entity_advanced_face(face))
}
