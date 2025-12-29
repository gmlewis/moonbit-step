///|
/// SweepPath represents the information needed to sweep a profile along a path.
pub(all) struct SweepPath {
  points : Array[(Double, Double, Double)]
  normals : Array[(Double, Double, Double)]
  tangents : Array[(Double, Double, Double)]
}

///|
/// SweepProfile represents a 2D profile to be swept along a path.
pub(all) struct SweepProfile {
  center : (Double, Double, Double)
  vertices : Array[(Double, Double, Double)]
  // normal_dir points in the direction of extrusion
  normal_dir : (Double, Double, Double)
  // right_dir points to the "right" side of the profile when looking along normal_dir
  right_dir : (Double, Double, Double)
}

///|
/// Sweep::new generates a new Shape by sweeping a 2D profile along a 3D path.
/// Note that the resulting Shape has no end caps; both ends are open.
// pub fn Sweep::new(path : SweepPath, profile : SweepProfile) -> Shape {
//   // TODO
//   {}
// }
