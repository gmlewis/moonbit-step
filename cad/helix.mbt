///|
pub fn helix_path(
  pos? : (Double, Double, Double) = (0.0, 0.0, 0.0),
  size~ : (Double, Double, Double),
  num_turns? : Double = 1.0,
  num_segs_per_turn? : Int = 6,
  start_angle? : Double = 0.0,
  clockwise? : Bool = true,
) -> Array[(Double, Double, Double)] {
  let (x0, y0, z0) = pos
  let (dx, dy, dz) = size
  let total_segs = (num_turns * num_segs_per_turn.to_double()).to_int()
  let verts = []
  let dt = if clockwise { -360.0 * num_turns } else { 360.0 * num_turns }
  for seg_idx in 0..=total_segs {
    let t = seg_idx.to_double() / total_segs.to_double()
    let angle_deg = start_angle + t * dt
    let angle_rad = angle_deg * @math.PI / 180.0
    let x = x0 + dx * @math.cos(angle_rad)
    let y = y0 + dy * @math.sin(angle_rad)
    let z = z0 + t * dz
    verts.push((x, y, z))
  }
  return verts
}

///|
test "helix_path generates correct number of points" {
  let path = helix_path(
    size=(10.0, 10.0, 20.0),
    num_turns=1.0,
    num_segs_per_turn=4,
    start_angle=0.0,
  )
  inspect(
    path,
    content="[(10, 0, 0), (6.123233995736766e-16, -10, 5), (-10, -1.2246467991473533e-15, 10), (-1.8369701987210296e-15, 10, 15), (10, 2.4492935982947065e-15, 20)]",
  )
}
