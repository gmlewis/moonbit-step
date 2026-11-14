///|
/// rect_loop returns a counter-clockwise rectangular loop in the XY plane.
fn rect_loop(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[@cad.ProfileSegment] {
  [
    @cad.SegmentLine((x0, y0), (x1, y0)),
    @cad.SegmentLine((x1, y0), (x1, y1)),
    @cad.SegmentLine((x1, y1), (x0, y1)),
    @cad.SegmentLine((x0, y1), (x0, y0)),
  ]
}

///|
/// circle_loop returns a counter-clockwise full circle as four minor arcs.
fn circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let centre = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), centre),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), centre),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), centre),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), centre),
  ]
}

///|
/// slot_loop returns a counter-clockwise obround loop whose long axis is X.
fn slot_loop(
  cx : Double,
  cy : Double,
  length_mm : Double,
  width_mm : Double,
) -> Array[@cad.ProfileSegment] {
  let r = width_mm / 2.0
  let left = cx - (length_mm / 2.0 - r)
  let right = cx + (length_mm / 2.0 - r)
  [
    @cad.SegmentLine((left, cy - r), (right, cy - r)),
    @cad.SegmentArc((right, cy - r), (right, cy + r), (right, cy)),
    @cad.SegmentLine((right, cy + r), (left, cy + r)),
    @cad.SegmentArc((left, cy + r), (left, cy - r), (left, cy)),
  ]
}

///|
/// stadium_loop returns a counter-clockwise stadium (two semicircular ends of
/// radius `radius` at `x = +/- center_offset` joined by straight edges).
fn stadium_loop(
  center_offset : Double,
  radius : Double,
  segments_per_arc~ : Int32 = 4,
) -> Array[@cad.ProfileSegment] {
  let segs = if segments_per_arc < 2 { 2 } else { segments_per_arc }
  let segments : Array[@cad.ProfileSegment] = []
  let x = center_offset
  // Counter-clockwise: bottom straight edge, right semicircle from bottom to
  // top, top straight edge, then the left semicircle from top to bottom.
  let start = (x, -radius)
  segments.push(@cad.SegmentLine((-x, -radius), start))
  let pi = @math.PI
  let step = pi / segs.to_double()
  let mut previous = start
  for i in 0..<segs {
    let a1 = -pi / 2.0 + step * (i + 1).to_double()
    let p0 = (x + radius * @math.cos(a1), radius * @math.sin(a1))
    segments.push(@cad.SegmentArc(previous, p0, (x, 0.0)))
    previous = p0
  }
  segments.push(@cad.SegmentLine(previous, (-x, radius)))
  let mut previous_left = (-x, radius)
  for i in 0..<segs {
    let a1 = pi / 2.0 + step * (i + 1).to_double()
    let p0 = (-x + radius * @math.cos(a1), radius * @math.sin(a1))
    segments.push(@cad.SegmentArc(previous_left, p0, (-x, 0.0)))
    previous_left = p0
  }
  segments
}

///|
/// rounded_rect_loop returns a counter-clockwise rectangle with rounded
/// corners of radius `radius`.
fn rounded_rect_loop(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  if radius <= 0.0 {
    return rect_loop(x0, y0, x1, y1)
  }
  let r = radius
  [
    @cad.SegmentLine((x0 + r, y0), (x1 - r, y0)),
    @cad.SegmentArc((x1 - r, y0), (x1, y0 + r), (x1 - r, y0 + r)),
    @cad.SegmentLine((x1, y0 + r), (x1, y1 - r)),
    @cad.SegmentArc((x1, y1 - r), (x1 - r, y1), (x1 - r, y1 - r)),
    @cad.SegmentLine((x1 - r, y1), (x0 + r, y1)),
    @cad.SegmentArc((x0 + r, y1), (x0, y1 - r), (x0 + r, y1 - r)),
    @cad.SegmentLine((x0, y1 - r), (x0, y0 + r)),
    @cad.SegmentArc((x0, y0 + r), (x0 + r, y0), (x0 + r, y0 + r)),
  ]
}

///|
/// mechanism_common_checks validates a list of positive dimensions and returns
/// the first typed error.
fn mechanism_checks(
  values : Array[(String, Double)],
) -> Result[Unit, @common.SpecError] {
  for entry in values {
    let (name, value) = entry
    match @common.require_positive(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
/// mechanism_non_negative_checks validates a list of non-negative dimensions.
fn mechanism_non_negative_checks(
  values : Array[(String, Double)],
) -> Result[Unit, @common.SpecError] {
  for entry in values {
    let (name, value) = entry
    match @common.require_non_negative(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  Ok(())
}

///|
/// mechanism_cylinder_z returns a cylinder along +Z from `z = 0`.
fn mechanism_cylinder_z(diameter_mm : Double, length_mm : Double) -> @cad.Shape {
  @cad.RevolvedProfile::cylinder(diameter_mm, length_mm).as_shape()
}

///|
/// circle_points returns a counter-clockwise polygon approximation of a
/// circle, for hole loops in `ExtrudedProfile`.
fn circle_points(
  cx : Double,
  cy : Double,
  radius : Double,
  segments~ : Int32 = 16,
) -> Array[(Double, Double)] {
  let count = if segments < 8 { 8 } else { segments }
  let points : Array[(Double, Double)] = []
  for i in 0..<count {
    let angle = 2.0 * @math.PI * i.to_double() / count.to_double()
    points.push(
      (cx + radius * @math.cos(angle), cy + radius * @math.sin(angle)),
    )
  }
  points
}

///|
/// mechanism_tube_z returns an annular tube along +Z from `z = 0`.
fn mechanism_tube_z(
  outer_diameter_mm : Double,
  inner_diameter_mm : Double,
  length_mm : Double,
) -> @cad.Shape {
  @cad.RevolvedProfile::tube(outer_diameter_mm, inner_diameter_mm, length_mm).as_shape()
}
