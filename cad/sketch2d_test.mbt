///|
fn sk_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn sk_hole_center(hole : Array[(Double, Double)]) -> (Double, Double) {
  let n = hole.length().to_double()
  hole.fold(init=(0.0, 0.0), fn(acc, p) { (acc.0 + p.0 / n, acc.1 + p.1 / n) })
}

///|
fn sk_winding_design(outer_cw : Bool, hole_cw : Bool) -> @cad.Design {
  let outer = @cad.Sketch2D::rect(100.0, 100.0).outer
  let hole = @cad.Sketch2D::rect(20.0, 20.0).outer
  let outer = if outer_cw { outer.rev() } else { outer }
  let hole = if hole_cw { hole.rev() } else { hole }
  @cad.Design::new(name="winding").add(
    @cad.ExtrudedProfile::new(outer, 10.0, holes=[hole]).with_name("plate"),
  )
}

///|
async test "extruded profile normalizes outer and hole winding" {
  let canonical = sk_winding_design(false, true).to_step_file()
  for variant in [(true, false), (true, true), (false, false)] {
    assert_eq(sk_winding_design(variant.0, variant.1).to_step_file(), canonical)
  }
  // The winding test fixture is also used by the external volume check.
  let step = @cad.Design::new(name="winding")
    .add(
      @cad.ExtrudedProfile::new(
        @cad.Sketch2D::rect(100.0, 100.0).outer.rev(),
        10.0,
        holes=[@cad.Sketch2D::rect(20.0, 20.0).outer],
      ).with_name("plate"),
    )
    .to_step_file()
  @cad.write_text_file(step, Some("/tmp/sketch2d-winding.step"))
}

///|
test "sketch2d constructors make closed positive-area loops" {
  let sketches : Array[@cad.Sketch2D] = [
    @cad.Sketch2D::polygon([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)]),
    @cad.Sketch2D::rect(20.0, 10.0),
    @cad.Sketch2D::rounded_rect(20.0, 10.0, 3.0),
    @cad.Sketch2D::circle(5.0),
    @cad.Sketch2D::slot(30.0, 10.0),
    @cad.Sketch2D::stadium_link((0.0, 0.0), (40.0, 0.0), 8.0, 8.0),
    @cad.Sketch2D::link_arc((0.0, 0.0), (40.0, 0.0), 8.0, 6.0, 12.0),
    @cad.Sketch2D::spoked_wheel(50.0, 12.0, 4.0, 6, 5.0),
  ]
  for sketch in sketches {
    assert_true(sketch.outer.length() >= 3)
    assert_true(@cad.polygon_area_2d(sketch.outer) > 0.0)
  }
  assert_eq(
    @cad.Sketch2D::spoked_wheel(50.0, 12.0, 4.0, 6, 5.0).holes.length(),
    6,
  )
}

///|
test "sketch2d hole modifiers add holes at the requested positions" {
  let base = @cad.Sketch2D::rect(100.0, 100.0)
  let one = base.with_hole_circle(10.0, 0.0, diam=20.0)
  assert_eq(one.holes.length(), 1)
  let center = sk_hole_center(one.holes[0])
  assert_true(sk_close(center.0, 10.0))
  assert_true(sk_close(center.1, 0.0))

  let bolts = base.with_bolt_circle(0.0, 0.0, count=4, bcd=40.0, hole_diam=4.0)
  assert_eq(bolts.holes.length(), 4)
  for hole in bolts.holes {
    let c = sk_hole_center(hole)
    let radius = (c.0 * c.0 + c.1 * c.1).sqrt()
    assert_true(sk_close(radius, 20.0))
  }

  let poly = base.with_hole_polygon([(0.0, 0.0), (5.0, 0.0), (5.0, 5.0)])
  assert_eq(poly.holes.length(), 1)
  let slot = base.with_hole_slot(
    0.0,
    0.0,
    length=20.0,
    width=5.0,
    angle_deg=30.0,
  )
  assert_eq(slot.holes.length(), 1)
}

///|
test "punch_mate_holes adds a bolt circle and pilot bore" {
  let pattern = @cad.HolePattern::bolt_circle(
    count=4,
    bcd_mm=40.0,
    hole_diam_mm=4.4,
    pilot_diam_mm=12.7,
  )
  let punched = @cad.Sketch2D::rounded_rect(100.0, 100.0, 10.0).punch_mate_holes(
    0.0, 0.0, pattern,
  )
  assert_eq(punched.holes.length(), 5)
  let pilot = sk_hole_center(punched.holes[0])
  assert_true(sk_close(pilot.0, 0.0))
  assert_true(sk_close(pilot.1, 0.0))
  for i in 1..<=4 {
    let c = sk_hole_center(punched.holes[i])
    let radius = (c.0 * c.0 + c.1 * c.1).sqrt()
    assert_true(sk_close(radius, 20.0))
  }
}

///|
test "punch_mate_holes handles bearing seats and single bores" {
  let base = @cad.Sketch2D::rect(100.0, 100.0)
  let seat = base.punch_mate_holes(
    0.0,
    0.0,
    @cad.HolePattern::bearing_seat(outer_diam_mm=28.575, bore_diam_mm=12.7),
  )
  assert_eq(seat.holes.length(), 1)
  let seat_center = sk_hole_center(seat.holes[0])
  assert_true(sk_close(seat_center.0, 0.0))
  let seat_radius = sk_close(
    (seat.holes[0][0].0 * seat.holes[0][0].0 +
    seat.holes[0][0].1 * seat.holes[0][0].1).sqrt(),
    28.575 / 2.0 + 0.0,
  )
  assert_true(seat_radius)

  let bore = base.punch_mate_holes(
    10.0,
    0.0,
    @cad.HolePattern::single_bore(diam_mm=12.7),
    clearance_mm=0.2,
  )
  assert_eq(bore.holes.length(), 1)
  let c = sk_hole_center(bore.holes[0])
  assert_true(sk_close(c.0, 10.0))
  // Clearance is diametral, so the radius grows by half of it.
  let p = bore.holes[0][0]
  let r = ((p.0 - 10.0) * (p.0 - 10.0) + p.1 * p.1).sqrt()
  assert_true(sk_close(r, 12.7 / 2.0 + 0.1))
}

///|
test "sketch2d validates hole edge margins" {
  let good = @cad.Sketch2D::rect(100.0, 100.0).with_hole_circle(
    0.0,
    0.0,
    diam=20.0,
  )
  assert_eq(good.validate_edge_margins(5.0).length(), 0)

  let arc_link = @cad.Sketch2D::link_arc(
      (0.0, 0.0),
      (120.0, 0.0),
      22.0,
      22.0,
      28.0,
      segs=18,
    )
    .with_hole_circle(0.0, 0.0, diam=28.575, segs=24)
    .with_hole_circle(120.0, 0.0, diam=28.575, segs=24)
  assert_eq(arc_link.validate_edge_margins(3.0).length(), 0)

  let outside = @cad.Sketch2D::rect(100.0, 100.0).with_hole_circle(
    49.0,
    0.0,
    diam=10.0,
  )
  let outside_messages = outside.validate_edge_margins(1.0)
  assert_true(outside_messages.length() > 0)
  assert_true(outside_messages[0].contains("hole"))

  let tight = @cad.Sketch2D::rect(100.0, 100.0).with_hole_circle(
    40.0,
    0.0,
    diam=10.0,
  )
  assert_true(tight.validate_edge_margins(6.0).length() > 0)
  assert_eq(tight.validate_edge_margins(4.0).length(), 0)
}

///|
test "sketch2d extrudes on xy xz and yz planes" {
  let sketch = @cad.Sketch2D::rect(100.0, 40.0)

  let xy = sketch.extrude_on(@cad.Plane::XY, 10.0).bounding_box()
  assert_true(sk_close(xy.0, -50.0))
  assert_true(sk_close(xy.1, 50.0))
  assert_true(sk_close(xy.2, -20.0))
  assert_true(sk_close(xy.3, 20.0))
  assert_true(sk_close(xy.4, 0.0))
  assert_true(sk_close(xy.5, 10.0))

  let xz = sketch.extrude_on(@cad.Plane::XZ, 10.0).bounding_box()
  assert_true(sk_close(xz.0, -50.0))
  assert_true(sk_close(xz.1, 50.0))
  assert_true(sk_close(xz.2, -10.0))
  assert_true(sk_close(xz.3, 0.0))
  assert_true(sk_close(xz.4, -20.0))
  assert_true(sk_close(xz.5, 20.0))

  let yz = sketch.extrude_on(@cad.Plane::YZ, 10.0).bounding_box()
  assert_true(sk_close(yz.0, 0.0))
  assert_true(sk_close(yz.1, 10.0))
  assert_true(sk_close(yz.2, -20.0))
  assert_true(sk_close(yz.3, 20.0))
  assert_true(sk_close(yz.4, -50.0))
  assert_true(sk_close(yz.5, 50.0))

  let centered = sketch
    .extrude_on(@cad.Plane::XY, 10.0, centered=true)
    .bounding_box()
  assert_true(sk_close(centered.4, -5.0))
  assert_true(sk_close(centered.5, 5.0))

  let centered_xz = sketch
    .extrude_on(@cad.Plane::XZ, 10.0, centered=true)
    .bounding_box()
  assert_true(sk_close(centered_xz.0, -50.0))
  assert_true(sk_close(centered_xz.1, 50.0))
  assert_true(sk_close(centered_xz.2, -5.0))
  assert_true(sk_close(centered_xz.3, 5.0))
  assert_true(sk_close(centered_xz.4, -20.0))
  assert_true(sk_close(centered_xz.5, 20.0))

  let centered_yz = sketch
    .extrude_on(@cad.Plane::YZ, 10.0, centered=true)
    .bounding_box()
  assert_true(sk_close(centered_yz.0, -5.0))
  assert_true(sk_close(centered_yz.1, 5.0))
  assert_true(sk_close(centered_yz.2, -20.0))
  assert_true(sk_close(centered_yz.3, 20.0))
  assert_true(sk_close(centered_yz.4, -50.0))
  assert_true(sk_close(centered_yz.5, 50.0))
}

///|
test "sketch2d fillet corners rounds a rectangle" {
  let filleted = @cad.Sketch2D::rect(100.0, 60.0).fillet_corners(5.0)
  assert_true(filleted.outer.length() > 4)
  let area = @cad.polygon_area_2d(filleted.outer)
  assert_true(area > 0.0)
  assert_true(area < 6000.0)
  let box = filleted.extrude_on(@cad.Plane::XY, 2.0).bounding_box()
  assert_true(sk_close(box.0, -50.0))
  assert_true(sk_close(box.1, 50.0))
  assert_true(sk_close(box.2, -30.0))
  assert_true(sk_close(box.3, 30.0))
}

///|
test "sketch2d translate and rotate move the profile" {
  let moved = @cad.Sketch2D::rect(20.0, 10.0).translate(10.0, 5.0)
  let box = moved.extrude_on(@cad.Plane::XY, 1.0).bounding_box()
  assert_true(sk_close(box.0, 0.0))
  assert_true(sk_close(box.1, 20.0))
  assert_true(sk_close(box.2, 0.0))
  assert_true(sk_close(box.3, 10.0))

  let rotated = moved.rotate_deg(90.0)
  let rotated_box = rotated.extrude_on(@cad.Plane::XY, 1.0).bounding_box()
  assert_true(sk_close(rotated_box.0, -10.0))
  assert_true(sk_close(rotated_box.1, 0.0))
  assert_true(sk_close(rotated_box.2, 0.0))
  assert_true(sk_close(rotated_box.3, 20.0))
}

///|
async test "sketch2d wheel and link export watertight step files" {
  let wheel = @cad.Sketch2D::spoked_wheel(60.0, 15.0, 4.0, 8, 6.0).extrude_on(
    @cad.Plane::XY,
    8.0,
  )
  let link = @cad.Sketch2D::link_arc((0.0, 0.0), (100.0, 0.0), 12.0, 10.0, 20.0).extrude_on(
    @cad.Plane::XZ,
    6.0,
  )
  let yz = @cad.Sketch2D::rect(30.0, 20.0).extrude_on(@cad.Plane::YZ, 5.0)
  let design = @cad.Design::new(name="sketch2d-test")
    .add(wheel)
    .add(link)
    .add(yz)
  let step = design.to_step_file()
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))

  design.write_step_file(Some("/tmp/sketch2d-wheel-link.step"))
  assert_true(@fs.exists("/tmp/sketch2d-wheel-link.step"))
  @cad.Design::new(name="sketch2d-wheel")
  .add(wheel)
  .write_step_file(Some("/tmp/sketch2d-wheel.step"))
  @cad.Design::new(name="sketch2d-link")
  .add(link)
  .write_step_file(Some("/tmp/sketch2d-link.step"))
  @cad.Design::new(name="sketch2d-yz")
  .add(yz)
  .write_step_file(Some("/tmp/sketch2d-yz.step"))
}

///|
test "sketch2d validates hole-to-hole clearance" {
  let overlapping = @cad.Sketch2D::rect(200.0, 200.0)
    .with_hole_circle(0.0, 0.0, diam=20.0)
    .with_hole_circle(5.0, 0.0, diam=20.0)
  let messages = overlapping.validate_edge_margins(2.0)
  assert_eq(messages.length(), 1)
  assert_true(messages[0].contains("hole 1 and hole 2"))
  assert_true(messages[0].contains("overlap"))

  let separated = @cad.Sketch2D::rect(200.0, 200.0)
    .with_hole_circle(0.0, 0.0, diam=10.0)
    .with_hole_circle(40.0, 0.0, diam=10.0)
  assert_eq(separated.validate_edge_margins(2.0).length(), 0)

  let close = @cad.Sketch2D::rect(200.0, 200.0)
    .with_hole_circle(0.0, 0.0, diam=10.0)
    .with_hole_circle(11.0, 0.0, diam=10.0)
  let close_messages = close.validate_edge_margins(2.0)
  assert_eq(close_messages.length(), 1)
  assert_true(close_messages[0].contains("closer than"))
}
