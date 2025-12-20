///|
pub fn Cuboid::new(sx : Double, sy : Double, sz : Double) -> Shape {
  Shape::Cuboid({ sx, sy, sz })
}

///|
pub fn CalibrationChamferBlock::new(
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  chamfer_size_mm? : Double = 1.0,
  fillet_radius_mm? : Double = 0.0,
  fillet_segments? : Int = 8,
) -> Shape {
  Shape::CalibrationChamferBlock({
    length_mm,
    width_mm,
    height_mm,
    chamfer_size_mm,
    fillet_radius_mm,
    fillet_segments,
  })
}

///|
pub fn Profile2D::circle(
  diameter : Double,
  segments? : Int = 64,
) -> Array[(Double, Double)] {
  let radius = diameter / 2.0
  let out : Array[(Double, Double)] = []
  let n = if segments < 3 { 3 } else { segments }
  for i in 0..<n {
    let phi = Double::from_int(i) * 2.0 * @math.PI / Double::from_int(n)
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
pub fn ExtrudedProfile::new(
  outer : Array[(Double, Double)],
  height_mm : Double,
  holes? : Array[Array[(Double, Double)]] = [],
) -> Shape {
  Shape::ExtrudedProfile({ profile: { outer, holes }, height_mm })
}

///|
pub fn Shape::with_name(self : Shape, name : String) -> SceneNode {
  SceneNode::{
    shape: self,
    name,
    color: Rgb::orange(),
    tx: 0.0,
    ty: 0.0,
    tz: 0.0,
  }
}

///|
pub fn SceneNode::with_color(self : SceneNode, color : Rgb) -> SceneNode {
  { ..self, color, }
}

///|
pub fn SceneNode::translate(
  self : SceneNode,
  x? : Double = 0.0,
  y? : Double = 0.0,
  z? : Double = 0.0,
) -> SceneNode {
  { ..self, tx: self.tx + x, ty: self.ty + y, tz: self.tz + z }
}
