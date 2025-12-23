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
pub enum Shape {
  Cuboid(Cuboid)
  CalibrationChamferBlock(CalibrationChamferBlock)
  ExtrudedProfile(ExtrudedProfile)
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
