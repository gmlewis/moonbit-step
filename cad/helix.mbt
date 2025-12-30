///|
pub fn helix_path(
  pos? : Vec3 = (0.0, 0.0, 0.0),
  size_per_turn? : Vec3 = (1.0, 1.0, 1.0),
  num_turns? : Double = 1.0,
  num_segs_per_turn? : Int = 36,
  start_angle? : Double = 0.0,
  clockwise? : Bool = true,
) -> SweepPath {
  let max_angle = 2.0 * @math.PI * num_turns
  let total_segments = @math.ceil(num_turns * num_segs_per_turn.to_double())
  if total_segments < 1 {
    return { points: [], normals: [], tangents: [] }
  }
  let capacity = 1 + total_segments.to_int()
  let points = Array::new(capacity~)
  let normals = Array::new(capacity~)
  let tangents = Array::new(capacity~)

  //
  let angle_delta = max_angle / total_segments
  let delta_z = size_per_turn.2 * num_turns / total_segments
  let direction = if clockwise { -1.0 } else { 1.0 }
  let start_angle = @math.PI * start_angle / 180
  for seg_idx in 0..<capacity {
    let angle = direction * (start_angle + seg_idx.to_double() * angle_delta)
    let cos_angle = @math.cos(angle)
    let sin_angle = @math.sin(angle)
    let x = pos.0 + size_per_turn.0 * cos_angle
    let y = pos.1 + size_per_turn.1 * sin_angle
    let z = pos.2 + seg_idx.to_double() * delta_z
    let point = (x, y, z)
    points.push(point)
    let tx = -direction * sin_angle
    let ty = direction * cos_angle
    let tz = 0.0
    let tangent = (tx, ty, tz)
    tangents.push(normalize(tangent))
    let nx = cos_angle
    let ny = sin_angle
    let nz = 0.0
    let normal = (nx, ny, nz)
    let normal = normalize(cross(normal, tangent))
    normals.push(normal)
  }
  { points, normals, tangents }
}

///|
fn normalize(v : Vec3) -> Vec3 {
  let len = Double::sqrt(v.0 * v.0 + v.1 * v.1 + v.2 * v.2)
  if len == 0.0 {
    (0.0, 0.0, 0.0)
  } else {
    (v.0 / len, v.1 / len, v.2 / len)
  }
}

///|
fn cross(a : Vec3, b : Vec3) -> Vec3 {
  (a.1 * b.2 - a.2 * b.1, a.2 * b.0 - a.0 * b.2, a.0 * b.1 - a.1 * b.0)
}

///|
test "helix_path generates correct number of points" {
  let path = helix_path(
    size_per_turn=(10.0, 10.0, 20.0),
    num_turns=2.0,
    num_segs_per_turn=4,
    start_angle=0.0,
  )
  inspect(
    path.points,
    content="[(10, 0, 0), (6.123233995736766e-16, -10, 5), (-10, -1.2246467991473533e-15, 10), (-1.8369701987210296e-15, 10, 15), (10, 2.4492935982947065e-15, 20), (3.061616997868383e-15, -10, 25), (-10, -3.673940397442059e-15, 30), (-4.2862637970157365e-15, 10, 35), (10, 4.898587196589413e-15, 40)]",
  )
  inspect(
    path.normals,
    content="[(0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1)]",
  )
  inspect(
    path.tangents,
    content="[(0, -1, 0), (-1, -6.123233995736766e-17, 0), (-1.2246467991473532e-16, 1, 0), (1, 1.8369701987210297e-16, 0), (2.4492935982947064e-16, -1, 0), (-1, -3.061616997868383e-16, 0), (-3.6739403974420594e-16, 1, 0), (1, 4.286263797015736e-16, 0), (4.898587196589413e-16, -1, 0)]",
  )
  // Now rotate it 180 degrees
  let path = helix_path(
    size_per_turn=(10.0, 10.0, 20.0),
    num_turns=1.0,
    num_segs_per_turn=4,
    start_angle=180.0,
  )
  inspect(
    path.points,
    content="[(-10, -1.2246467991473533e-15, 0), (-1.8369701987210296e-15, 10, 5), (10, 2.4492935982947065e-15, 10), (3.061616997868383e-15, -10, 15), (-10, -3.673940397442059e-15, 20)]",
  )
  inspect(
    path.normals,
    content="[(0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1), (0, 0, -1)]",
  )
  inspect(
    path.tangents,
    content="[(-1.2246467991473532e-16, 1, 0), (1, 1.8369701987210297e-16, 0), (2.4492935982947064e-16, -1, 0), (-1, -3.061616997868383e-16, 0), (-3.6739403974420594e-16, 1, 0)]",
  )
}
