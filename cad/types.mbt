///|
pub struct Rgb {
  r : Double
  g : Double
  b : Double
}

///|
pub fn Rgb::new(r : Double, g : Double, b : Double) -> Rgb {
  { r, g, b }
}

///|
pub fn Rgb::orange() -> Rgb {
  { r: 1.0, g: 0.6, b: 0.0 }
}

///|
pub fn Rgb::blue() -> Rgb {
  { r: 0.2, g: 0.6, b: 1.0 }
}

///|
pub fn Rgb::grey() -> Rgb {
  { r: 0.2, g: 0.2, b: 0.2 }
}

///|
pub fn Rgb::purple() -> Rgb {
  { r: 0.5, g: 0.0, b: 0.5 }
}

///|
pub fn Rgb::magenta() -> Rgb {
  { r: 1.0, g: 0.0, b: 1.0 }
}

///|
pub fn Rgb::white() -> Rgb {
  { r: 1.0, g: 1.0, b: 1.0 }
}

///|
pub fn Rgb::black() -> Rgb {
  { r: 0.0, g: 0.0, b: 0.0 }
}

///|
pub fn Rgb::green() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.0 }
}

///|
pub fn Rgb::red() -> Rgb {
  { r: 0.8, g: 0.0, b: 0.0 }
}

///|
pub fn Rgb::cyan() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.8 }
}

///|
pub struct Profile2D {
  outer : Array[(Double, Double)]
  holes : Array[Array[(Double, Double)]]
}

///|
pub struct Cuboid {
  sx : Double
  sy : Double
  sz : Double
}

///|
pub struct CalibrationChamferBlock {
  length_mm : Double
  width_mm : Double
  height_mm : Double
  chamfer_size_mm : Double
  fillet_radius_mm : Double
  fillet_segments : Int
}

///|
pub struct ExtrudedProfile {
  profile : Profile2D
  height_mm : Double
}

///|
pub struct SweptProfile {
  path : SweepPath
  profile : SweepProfile
}

///|
pub enum Shape {
  Cuboid(Cuboid)
  CalibrationChamferBlock(CalibrationChamferBlock)
  ExtrudedProfile(ExtrudedProfile)
  SweptProfile(SweptProfile)
}

///|
pub struct SceneNode {
  shape : Shape
  name : String
  color : Rgb
  tx : Double
  ty : Double
  tz : Double
  rx : Double // rotation X in degrees
  ry : Double // rotation Y in degrees
  rz : Double // rotation Z in degrees
}

///|
pub(all) enum Face {
  Top
  Bottom
  Front
  Back
  Left
  Right
}

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
/// SweepProfile::new returns a new SweepProfile.
pub fn SweepProfile::new(
  vertices : Array[(Double, Double, Double)],
  center? : (Double, Double, Double) = (0.0, 0.0, 0.0),
  normal_dir? : (Double, Double, Double) = (0.0, 1.0, 0.0),
  right_dir? : (Double, Double, Double) = (1.0, 0.0, 0.0),
) -> SweepProfile {
  { center, vertices, normal_dir, right_dir }
}
