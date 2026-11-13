///|
fn rev_count(haystack : String, needle : String) -> Int32 {
  let parts = haystack.split(needle).collect()
  parts.length() - 1
}

///|
test "revolved cylinder has analytic cylinder and planar caps" {
  let shape = RevolvedProfile::cylinder(10.0, 5.0).as_shape()
  let (x0, x1, _y0, _y1, z0, z1) = shape.bounding_box()
  assert_true((x0 - -5.0).abs() < 1.0e-9)
  assert_true((x1 - 5.0).abs() < 1.0e-9)
  assert_true((z0 - 0.0).abs() < 1.0e-9)
  assert_true((z1 - 5.0).abs() < 1.0e-9)
  let step = Design::new(name="rev-cyl")
    .add(shape.with_name("cyl"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 3)
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "PLANE("), 2)
  assert_eq(rev_count(step, "CIRCLE("), 2)
  assert_eq(rev_count(step, "LINE("), 1)
}

///|
test "revolved frustum has an analytic conical surface" {
  let shape = RevolvedProfile::frustum(4.0, 2.0, 6.0).as_shape()
  let (x0, x1, _y0, _y1, z0, z1) = shape.bounding_box()
  assert_true((x0 - -4.0).abs() < 1.0e-9)
  assert_true((x1 - 4.0).abs() < 1.0e-9)
  assert_true((z0 - 0.0).abs() < 1.0e-9)
  assert_true((z1 - 6.0).abs() < 1.0e-9)
  let step = Design::new(name="rev-frustum")
    .add(shape.with_name("frustum"))
    .to_step_file()
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "PLANE("), 2)
  assert_eq(rev_count(step, "CIRCLE("), 2)
}

///|
test "revolved cone terminates at an axis pole" {
  let shape = RevolvedProfile::cone(3.0, 4.0).as_shape()
  let step = Design::new(name="rev-cone")
    .add(shape.with_name("cone"))
    .to_step_file()
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "PLANE("), 1)
  assert_eq(rev_count(step, "CIRCLE("), 1)
}

///|
test "revolved sphere is one spherical face with a seam" {
  let shape = RevolvedProfile::sphere(10.0).as_shape()
  let (x0, x1, _y0, _y1, z0, z1) = shape.bounding_box()
  assert_true((x0 - -5.0).abs() < 1.0e-6)
  assert_true((x1 - 5.0).abs() < 1.0e-6)
  assert_true((z0 - -5.0).abs() < 1.0e-6)
  assert_true((z1 - 5.0).abs() < 1.0e-6)
  let step = Design::new(name="rev-sphere")
    .add(shape.with_name("ball"))
    .to_step_file()
  assert_eq(rev_count(step, "SPHERICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "ADVANCED_FACE("), 1)
  // One meridian seam circle; no equator circle.
  assert_eq(rev_count(step, "CIRCLE("), 1)
  assert_eq(rev_count(step, "PLANE("), 0)
}

///|
test "sphere cap is a disc plus a spherical face" {
  let shape = RevolvedProfile::sphere_cap(4.0, 3.0).as_shape()
  let (x0, x1, _y0, _y1, z0, z1) = shape.bounding_box()
  assert_true((x0 - -4.0).abs() < 1.0e-6)
  assert_true((x1 - 4.0).abs() < 1.0e-6)
  assert_true((z0 - 0.0).abs() < 1.0e-9)
  assert_true((z1 - 3.0).abs() < 1.0e-6)
  let step = Design::new(name="rev-cap")
    .add(shape.with_name("cap"))
    .to_step_file()
  assert_eq(rev_count(step, "SPHERICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "PLANE("), 1)
}

///|
test "closed annular profile yields a bored ring with an inward bore face" {
  let ring = RevolvedProfile::polyline(
    [(2.0, 0.0), (5.0, 0.0), (5.0, 2.0), (2.0, 2.0)],
    closed=true,
  )
  inspect(ring.validate() is Ok(_), content="true")
  let step = Design::new(name="rev-ring")
    .add(ring.as_shape().with_name("ring"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 4)
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "PLANE("), 2)
  assert_eq(rev_count(step, "CIRCLE("), 4)
}

///|
test "off-axis arc bands produce toroidal faces" {
  let torus = RevolvedProfile::new([
    RevArc((4.0, 0.0), (5.0, 1.0), (5.0, 0.0)),
    RevArc((5.0, 1.0), (6.0, 0.0), (5.0, 0.0)),
    RevArc((6.0, 0.0), (5.0, -1.0), (5.0, 0.0)),
    RevArc((5.0, -1.0), (4.0, 0.0), (5.0, 0.0)),
  ])
  inspect(torus.validate() is Ok(_), content="true")
  let step = Design::new(name="rev-torus")
    .add(torus.as_shape().with_name("torus"))
    .to_step_file()
  assert_eq(rev_count(step, "TOROIDAL_SURFACE("), 4)
  assert_eq(rev_count(step, "ADVANCED_FACE("), 4)
  assert_eq(rev_count(step, "SPHERICAL_SURFACE("), 0)
}

///|
test "invalid revolved profiles are rejected" {
  // An open chain that ends away from the axis cannot bound a solid.
  let open = RevolvedProfile::new([
    RevLine((1.0, 0.0), (2.0, 0.0)),
    RevLine((2.0, 0.0), (2.0, 1.0)),
  ])
  inspect(open.validate() is Err(NotClosed), content="true")
  // A discontinuous chain is rejected.
  let gap = RevolvedProfile::new([
    RevLine((0.0, 0.0), (2.0, 0.0)),
    RevLine((3.0, 0.0), (3.0, 1.0)),
  ])
  inspect(gap.validate() is Err(_), content="true")
  // A reversed-winding profile is normalized, not rejected.
  let reversed = RevolvedProfile::new([
    RevLine((0.0, 5.0), (5.0, 5.0)),
    RevLine((5.0, 5.0), (5.0, 0.0)),
    RevLine((5.0, 0.0), (0.0, 0.0)),
  ])
  inspect(reversed.validate() is Ok(_), content="true")
}

///|
test "chamfered cylinder is one cylinder and two cones, never a facet ring" {
  let shape = RevolvedProfile::chamfered_cylinder(
    10.0,
    6.0,
    bottom_chamfer=1.0,
    top_chamfer=1.0,
  ).as_shape()
  let step = Design::new(name="rev-chamfer")
    .add(shape.with_name("chamfered"))
    .to_step_file()
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "PLANE("), 2)
  assert_eq(rev_count(step, "ADVANCED_FACE("), 5)
}

///|
test "revolved tube is an analytic annulus with two cylinders" {
  let shape = RevolvedProfile::tube(12.0, 6.0, 3.0).as_shape()
  let step = Design::new(name="rev-tube")
    .add(shape.with_name("tube"))
    .to_step_file()
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 0)
  assert_eq(rev_count(step, "PLANE("), 2)
  assert_eq(rev_count(step, "ADVANCED_FACE("), 4)
}

///|
test "chamfered tube puts a cone at every rim" {
  let shape = RevolvedProfile::chamfered_tube(
    12.0,
    6.0,
    4.0,
    outer_bottom_chamfer=0.5,
    outer_top_chamfer=0.5,
    inner_bottom_chamfer=0.5,
    inner_top_chamfer=0.5,
  ).as_shape()
  let step = Design::new(name="rev-ctube")
    .add(shape.with_name("ctube"))
    .to_step_file()
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 4)
  assert_eq(rev_count(step, "PLANE("), 2)
}

///|
test "cup has an analytic bore, top chamfer, and bore lead-in cone" {
  let shape = RevolvedProfile::cup(
    10.0,
    5.0,
    6.0,
    1.5,
    top_chamfer=0.6,
    bore_lead_in=0.4,
  ).as_shape()
  let step = Design::new(name="rev-cup")
    .add(shape.with_name("cup"))
    .to_step_file()
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 2)
  assert_eq(rev_count(step, "PLANE("), 3)
}

///|
test "extruded polygon with a round bore has an analytic cylinder" {
  let outline = Profile2D::centered_rect(20.0, 20.0)
  let shape = ExtrudedProfile::new(outline, 5.0, round_bore=((0.0, 0.0), 6.0))
  let step = Design::new(name="bored-plate")
    .add(shape.with_name("plate"))
    .to_step_file()
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "CIRCLE("), 2)
  // Four outer side quads, two annular caps, one bore wall.
  assert_eq(rev_count(step, "ADVANCED_FACE("), 7)
}
