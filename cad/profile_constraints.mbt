///|
// Deterministic 2D constraint helpers.
//
// A full sketch solver (MakerCad's dlineate) infers positions from relations.
// This module keeps the same intent vocabulary but computes the answer
// explicitly: every helper returns concrete `Vec2` coordinates, so a STEP file
// depends only on the numbers it is given and stays diffable.
//
// The rules are construction rules, not constraints solved at export time:
// "a bolt circle of n holes on radius r" is a point-array computation.

///|
/// point_on_circle returns the point at `angle_deg` on a circle of `radius`
/// centered at the origin.
pub fn point_on_circle(radius : Double, angle_deg : Double) -> Vec2 {
  let a = angle_deg * @math.PI / 180.0
  (radius * @math.cos(a), radius * @math.sin(a))
}

///|
/// midpoint returns the center of the segment `a`-`b`.
pub fn midpoint(a : Vec2, b : Vec2) -> Vec2 {
  ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0)
}

///|
/// project_point_to_line returns the perpendicular foot of `p` on the infinite
/// line through `a` and `b`. A degenerate line (`a == b`) returns `a`.
pub fn project_point_to_line(p : Vec2, a : Vec2, b : Vec2) -> Vec2 {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let denom = dx * dx + dy * dy
  if denom == 0.0 {
    return a
  }
  let t = ((p.0 - a.0) * dx + (p.1 - a.1) * dy) / denom
  (a.0 + t * dx, a.1 + t * dy)
}

///|
/// bolt_circle returns `count` hole centers evenly spaced on `radius`, starting
/// at `start_angle_deg` (measured counter-clockwise from +X).
pub fn bolt_circle(
  count : Int32,
  radius : Double,
  start_angle_deg~ : Double = 0.0,
) -> Array[Vec2] {
  let n = if count < 1 { 1 } else { count }
  let step = 360.0 / n.to_double()
  let out : Array[Vec2] = []
  for i in 0..<n {
    out.push(point_on_circle(radius, start_angle_deg + i.to_double() * step))
  }
  out
}

///|
/// grid_of_holes returns `cols * rows` centers on a rectangular pitch, centered
/// on `center` and ordered row-major (all columns of row 0, then row 1, ...).
pub fn grid_of_holes(
  cols : Int32,
  rows : Int32,
  pitch_x : Double,
  pitch_y : Double,
  center~ : Vec2 = (0.0, 0.0),
) -> Array[Vec2] {
  let c = if cols < 1 { 1 } else { cols }
  let r = if rows < 1 { 1 } else { rows }
  let x0 = center.0 - (c - 1).to_double() * pitch_x / 2.0
  let y0 = center.1 - (r - 1).to_double() * pitch_y / 2.0
  let out : Array[Vec2] = []
  for iy in 0..<r {
    for ix in 0..<c {
      out.push((x0 + ix.to_double() * pitch_x, y0 + iy.to_double() * pitch_y))
    }
  }
  out
}

///|
/// Profile2D::centered_circle is `Profile2D::circle` with explicit intent: a
/// counter-clockwise circle centered at the origin.
pub fn Profile2D::centered_circle(
  diameter : Double,
  segments~ : Int32 = 64,
) -> Array[Vec2] {
  Profile2D::circle(diameter, segments~)
}

///|
/// Profile2D::tangent_rect returns a rounded rectangle whose corner arcs are
/// tangent to all four sides (the radius is clamped to fit). It is the named
/// form of `Profile2D::rounded_rect`.
pub fn Profile2D::tangent_rect(
  width : Double,
  height : Double,
  radius : Double,
  segments~ : Int32 = 32,
) -> Array[Vec2] {
  Profile2D::rounded_rect(width, height, radius, segments~)
}

///|
/// grown_diameter applies a fit's per-face clearance to a hole diameter.
fn grown_diameter(diameter : Double, fit : Fit) -> Double {
  diameter + 2.0 * fit.per_face_mm()
}

///|
/// Profile2D::with_hole_at adds one clockwise circular hole centered at
/// `(x, y)`. `fit` grows the hole by its per-face clearance.
pub fn Profile2D::with_hole_at(
  self : Profile2D,
  x : Double,
  y : Double,
  diameter : Double,
  fit~ : Fit = Fit::Nominal,
  segments~ : Int32 = 32,
) -> Profile2D {
  let d = grown_diameter(diameter, fit)
  let hole = translate_pts(Profile2D::circle(d, segments~), x, y).rev()
  self.add_hole(hole)
}

///|
/// Profile2D::with_holes_at adds one clockwise circular hole at each location.
pub fn Profile2D::with_holes_at(
  self : Profile2D,
  locs : Array[Vec2],
  diameter : Double,
  fit~ : Fit = Fit::Nominal,
  segments~ : Int32 = 32,
) -> Profile2D {
  let d = grown_diameter(diameter, fit)
  let holes = self.holes.copy()
  for loc in locs {
    let hole = translate_pts(Profile2D::circle(d, segments~), loc.0, loc.1).rev()
    holes.push(hole)
  }
  { ..self, holes, }
}

///|
/// Profile2D::with_bolt_circle adds `count` evenly spaced holes on `radius`.
pub fn Profile2D::with_bolt_circle(
  self : Profile2D,
  count : Int32,
  radius : Double,
  hole_diameter : Double,
  start_angle_deg~ : Double = 0.0,
  fit~ : Fit = Fit::Nominal,
  segments~ : Int32 = 32,
) -> Profile2D {
  self.with_holes_at(
    bolt_circle(count, radius, start_angle_deg~),
    hole_diameter,
    fit~,
    segments~,
  )
}

///|
/// Profile2D::with_grid_of_holes adds a `cols * rows` grid of holes.
pub fn Profile2D::with_grid_of_holes(
  self : Profile2D,
  cols : Int32,
  rows : Int32,
  pitch_x : Double,
  pitch_y : Double,
  hole_diameter : Double,
  center~ : Vec2 = (0.0, 0.0),
  fit~ : Fit = Fit::Nominal,
  segments~ : Int32 = 32,
) -> Profile2D {
  self.with_holes_at(
    grid_of_holes(cols, rows, pitch_x, pitch_y, center~),
    hole_diameter,
    fit~,
    segments~,
  )
}
