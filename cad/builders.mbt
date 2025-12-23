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
pub fn Profile2D::rect(
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
  [(0.0, 0.0), (width, 0.0), (width, height), (0.0, height)]
}

///|
pub fn Profile2D::centered_rect(
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
  let hw = width / 2.0
  let hh = height / 2.0
  [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
}

///|
pub fn Profile2D::dovetail(
  width : Double,
  height : Double,
  angle : Double, // angle in degrees from vertical
) -> Array[(Double, Double)] {
  let angle_rad = angle * @math.PI / 180.0
  let dx = height * @math.tan(angle_rad)
  let half_width = width / 2.0
  [
    (-half_width, 0.0),
    (half_width, 0.0),
    (half_width + dx, height),
    (-half_width - dx, height),
  ]
}

///|
pub fn dovetail_base(
  width : Double,
  height : Double,
  length : Double,
  dovetail_width : Double,
  dovetail_height : Double,
  dovetail_angle : Double,
) -> Shape {
  let hw = width / 2.0
  let hh = height / 2.0
  let dhw = dovetail_width / 2.0
  let angle_rad = dovetail_angle * @math.PI / 180.0
  let dx = dovetail_height * @math.tan(angle_rad)

  // Construct a single CCW loop including the dovetail cutout at the top.
  let outer = [
    (-hw, hh),
    (-hw, -hh),
    (hw, -hh),
    (hw, hh),
    (dhw, hh),
    (dhw + dx, hh - dovetail_height),
    (-dhw - dx, hh - dovetail_height),
    (-dhw, hh),
  ]
  ExtrudedProfile::new(outer, length)
}

///|
pub fn dovetail_slider(
  width : Double,
  height : Double,
  length : Double,
  angle : Double,
  clearance? : Double = 0.0,
) -> Shape {
  // Apply clearance: narrow the width and shorten the height.
  let dt = Profile2D::dovetail(
    width - 2.0 * clearance,
    height - clearance,
    angle,
  )
  // Flip Y to match the groove orientation (neck at the top, pointing down).
  // We also reverse the order to maintain CCW orientation.
  let n = dt.length()
  let flipped = []
  for i in 0..<n {
    let p = dt[n - 1 - i]
    flipped.push((p.0, -p.1))
  }
  ExtrudedProfile::new(flipped, length)
}

///|
/// Profile2D::polygon returns a regular polygon with the given number of sides,
/// diameter, and optional rotation in degrees.
pub fn Profile2D::polygon(
  sides : Int,
  diameter : Double,
  rotation? : Double = 0.0,
) -> Array[(Double, Double)] {
  let n = if sides < 3 { 3 } else { sides }
  let radius = diameter / 2.0
  let angle_step = 2.0 * @math.PI / Double::from_int(n)
  let rotation_rad = rotation * @math.PI / 180.0
  let out = []
  for i in 0..<n {
    let phi = Double::from_int(i) * angle_step + rotation_rad
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
/// polygon_knob returns a Shape representing a polygonal knob with a polygonal
/// shaft hole.
pub fn polygon_knob(
  sides : Int,
  diameter : Double,
  height : Double,
  hole_sides : Int,
  hole_diameter : Double,
  hole_rotation? : Double = 0.0,
) -> Shape {
  let outer = Profile2D::polygon(sides, diameter)
  let hole = Profile2D::polygon(
    hole_sides,
    hole_diameter,
    rotation=hole_rotation,
  )
  // Hole must be reversed (CW) for standard STEP orientation if outer is CCW.
  let hole_reversed = hole.rev()
  ExtrudedProfile::new(outer, height, holes=[hole_reversed])
}

///|
/// hex_bit_holder returns a Shape representing a block with a grid of
/// hexagonal holes suitable for standard hex bits.
pub fn hex_bit_holder(
  rows : Int,
  cols : Int,
  bit_diameter_across_flats : Double,
  spacing : Double,
  height : Double,
) -> Shape {
  let d = bit_diameter_across_flats / @math.cos(30.0 * @math.PI / 180.0)
  let hex = Profile2D::polygon(6, d, rotation=30.0)
  let total_width = Double::from_int(cols) * spacing
  let total_length = Double::from_int(rows) * spacing
  let outer = Profile2D::rect(total_width, total_length)
  let holes = []
  for r in 0..<rows {
    for c in 0..<cols {
      let tx = Double::from_int(c) * spacing + spacing / 2.0
      let ty = Double::from_int(r) * spacing + spacing / 2.0
      holes.push(hex.map(fn(p) { (p.0 + tx, p.1 + ty) }).rev())
    }
  }
  ExtrudedProfile::new(outer, height, holes~)
}

///|
pub fn Profile2D::circle(
  diameter : Double,
  segments? : Int = 64,
) -> Array[(Double, Double)] {
  let radius = diameter / 2.0
  let n = if segments < 3 { 3 } else { segments }
  let angle_step = 2.0 * @math.PI / Double::from_int(n)
  let out = []
  for i in 0..<n {
    let phi = Double::from_int(i) * angle_step
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
pub fn Profile2D::arc(
  diameter : Double,
  start_angle : Double,
  end_angle : Double,
  segments? : Int = 32,
) -> Array[(Double, Double)] {
  let radius = diameter / 2.0
  let n = if segments < 2 { 2 } else { segments }
  let angle_step = (end_angle - start_angle) / Double::from_int(n)
  let out = []
  for i in 0..=n {
    let phi = start_angle + Double::from_int(i) * angle_step
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
    rx: 0.0,
    ry: 0.0,
    rz: 0.0,
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

///|
pub fn SceneNode::rotate_x(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, rx: self.rx + angle }
}

///|
pub fn SceneNode::rotate_y(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, ry: self.ry + angle }
}

///|
pub fn SceneNode::rotate_z(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, rz: self.rz + angle }
}
