///|
pub fn polygon_area_2d(pts : Array[Vec2]) -> Double {
  let n = pts.length()
  if n < 3 {
    return 0.0
  }
  let mut area = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    area = area + (pts[i].0 * pts[j].1 - pts[j].0 * pts[i].1)
  }
  area / 2.0
}

///|
pub fn force_ccw(pts : Array[Vec2]) -> Array[Vec2] {
  if polygon_area_2d(pts) < 0.0 {
    pts.rev()
  } else {
    pts
  }
}

///|
pub fn force_cw(pts : Array[Vec2]) -> Array[Vec2] {
  if polygon_area_2d(pts) > 0.0 {
    pts.rev()
  } else {
    pts
  }
}

///|
pub fn is_point_in_polygon(p : Vec2, poly : Array[Vec2]) -> Bool {
  let n = poly.length()
  if n < 3 {
    return false
  }
  let mut inside = false
  let (px, py) = p
  for i in 0..<n {
    let j = (i + 1) % n
    let (xi, yi) = poly[i]
    let (xj, yj) = poly[j]
    let intersect = (yi > py) != (yj > py) &&
      px < (xj - xi) * (py - yi) / (yj - yi) + xi
    if intersect {
      inside = !inside
    }
  }
  inside
}

///|
pub fn cycle_area_3d(pts : Array[Vec3], cycle : Array[Int]) -> Vec3 {
  let n = cycle.length()
  if n < 3 {
    return (0.0, 0.0, 0.0)
  }
  let mut ax = 0.0
  let mut ay = 0.0
  let mut az = 0.0
  for i in 0..<n {
    let j = (i + 1) % n
    let (x1, y1, z1) = pts[cycle[i]]
    let (x2, y2, z2) = pts[cycle[j]]
    ax = ax + (y1 * z2 - z1 * y2)
    ay = ay + (z1 * x2 - x1 * z2)
    az = az + (x1 * y2 - y1 * x2)
  }
  (ax / 2.0, ay / 2.0, az / 2.0)
}

///|
fn v_sub(a : Vec3, b : Vec3) -> Vec3 {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ax - bx, ay - by, az - bz)
}

///|
fn v_cross(a : Vec3, b : Vec3) -> Vec3 {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
}

///|
fn v_dot(a : Vec3, b : Vec3) -> Double {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  ax * bx + ay * by + az * bz
}

///|
fn v_len(a : Vec3) -> Double {
  let (x, y, z) = a
  Double::sqrt(x * x + y * y + z * z)
}

///|
fn v_norm(a : Vec3) -> Vec3 {
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
pub fn rotate_point(p : Vec3, rx : Double, ry : Double, rz : Double) -> Vec3 {
  let m = rotation_matrix(rx, ry, rz)
  apply_matrix(m, p)
}

///|
pub(all) struct Matrix3x3 {
  m00 : Double
  m01 : Double
  m02 : Double
  m10 : Double
  m11 : Double
  m12 : Double
  m20 : Double
  m21 : Double
  m22 : Double
}

///|
fn rotation_matrix(rx : Double, ry : Double, rz : Double) -> Matrix3x3 {
  let rad_x = rx * @math.PI / 180.0
  let rad_y = ry * @math.PI / 180.0
  let rad_z = rz * @math.PI / 180.0
  let sx = @math.sin(rad_x)
  let cx = @math.cos(rad_x)
  let sy = @math.sin(rad_y)
  let cy = @math.cos(rad_y)
  let sz = @math.sin(rad_z)
  let cz = @math.cos(rad_z)

  // Combined matrix Rz * Ry * Rx
  Matrix3x3::{
    m00: cy * cz,
    m01: sx * sy * cz - cx * sz,
    m02: cx * sy * cz + sx * sz,
    m10: cy * sz,
    m11: sx * sy * sz + cx * cz,
    m12: cx * sy * sz - sx * cz,
    m20: -sy,
    m21: sx * cy,
    m22: cx * cy,
  }
}

///|
fn apply_matrix(m : Matrix3x3, p : Vec3) -> Vec3 {
  let (x, y, z) = p
  (
    m.m00 * x + m.m01 * y + m.m02 * z,
    m.m10 * x + m.m11 * y + m.m12 * z,
    m.m20 * x + m.m21 * y + m.m22 * z,
  )
}

///|
fn multiply_matrices(a : Matrix3x3, b : Matrix3x3) -> Matrix3x3 {
  Matrix3x3::{
    m00: a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20,
    m01: a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21,
    m02: a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
    m10: a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20,
    m11: a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21,
    m12: a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
    m20: a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20,
    m21: a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21,
    m22: a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22,
  }
}

///|
pub fn matrix_to_euler(m : Matrix3x3) -> Vec3 {
  // Extract Euler angles from rotation matrix assuming order Rz * Ry * Rx
  let ry = -@math.asin(m.m20)
  if Double::abs(@math.cos(ry)) > 0.0001 {
    let rx = @math.atan2(m.m21, m.m22)
    let rz = @math.atan2(m.m10, m.m00)
    (rx * 180.0 / @math.PI, ry * 180.0 / @math.PI, rz * 180.0 / @math.PI)
  } else {
    // Gimbal lock
    let rx = 0.0
    let rz = @math.atan2(-m.m01, m.m11)
    (rx, ry * 180.0 / @math.PI, rz * 180.0 / @math.PI)
  }
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
  abort("edge not found between points \{a} and \{b}")
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
    oe_refs.push(ctx.oriented_edge(edge_ref, ori))
  }
  ctx.edge_loop(oe_refs)
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
  let a2p_ref = ctx.axis2_placement_3d(location_pt, axis_dir, ref_dir)
  let plane = @geometry.Plane::new("", a2p_ref)
  let plane_ref = ctx.add(@repository.any_entity_plane(plane))
  let loop_ref = face_loop(ctx, edges, verts_cycle)
  let fob_ref = ctx.face_outer_bound(loop_ref, true)
  ctx.advanced_face([fob_ref], plane_ref, true)
}

///|
fn add_plane_face_oriented(
  ctx : StepContext,
  edges : Array[EdgeInfo],
  pts : Array[Vec3],
  cp_refs : Array[@step.Ref],
  verts_cycle : Array[Int],
  expected_out : Vec3,
) -> @step.Ref {
  let area_vec = cycle_area_3d(pts, verts_cycle)
  let cycle = if v_dot(area_vec, expected_out) < 0.0 {
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
  pts : Array[Vec3],
  cp_refs : Array[@step.Ref],
  outer_cycle_in : Array[Int],
  hole_cycles_in : Array[Array[Int]],
  expected_out : Vec3,
) -> @step.Ref {
  let area_vec = cycle_area_3d(pts, outer_cycle_in)
  let outer_cycle = if v_dot(area_vec, expected_out) < 0.0 {
    reverse_cycle(outer_cycle_in)
  } else {
    outer_cycle_in
  }

  // Holes must be oriented opposite to the outer boundary for STEP faces.
  // We use the 3D area vector to ensure robustness regardless of orientation.
  let hole_cycles = hole_cycles_in.map(fn(hc) {
    let ha_vec = cycle_area_3d(pts, hc)
    // If hole has same orientation as outer (relative to expected_out), reverse it.
    if v_dot(ha_vec, expected_out) * v_dot(area_vec, expected_out) > 0.0 {
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
  let a2p_ref = ctx.axis2_placement_3d(cp_refs[b0], axis_ref, ref_ref)
  let plane = @geometry.Plane::new("", a2p_ref)
  let plane_ref = ctx.add(@repository.any_entity_plane(plane))

  //
  let outer_loop_ref = face_loop(ctx, edges, outer_cycle)
  let fob_ref = ctx.face_outer_bound(outer_loop_ref, true)

  //
  let bounds : Array[@step.Ref] = [fob_ref]
  bounds.push_iter(
    hole_cycles
    .iter()
    .map(fn(loop_pts) {
      let loop_ref = face_loop(ctx, edges, loop_pts)
      ctx.face_bound(loop_ref, true)
    }),
  )
  ctx.advanced_face(bounds, plane_ref, true)
}
