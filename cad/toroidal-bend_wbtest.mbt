///|
test "ToroidalBend solid and hollow analytic STEP geometry and volume" {
  let hollow_tb : ToroidalBend = {
    bend_radius_mm: 25.0,
    outer_diameter_mm: 20.0,
    inner_diameter_mm: 14.0,
    angle_deg: 90.0,
  }
  let hollow = ToroidalBend::new(25.0, 20.0, 90.0, inner_diameter_mm=14.0)
  let step_hollow = Design::new(name="torus-hollow")
    .add(hollow.with_name("hollow"))
    .to_step_file()
  inspect(step_hollow.split("CLOSED_SHELL(").count() - 1, content="1")
  inspect(step_hollow.split("ADVANCED_FACE(").count() - 1, content="4")
  inspect(step_hollow.split("TOROIDAL_SURFACE(").count() - 1, content="2")
  inspect(step_hollow.split("PLANE(").count() - 1, content="2")
  assert_false(step_hollow.contains("B_SPLINE_SURFACE_WITH_KNOTS("))
  let expected_hollow_vol = @math.PI *
    (10.0 * 10.0 - 7.0 * 7.0) *
    25.0 *
    (@math.PI / 2.0)
  assert_near(hollow_tb.volume(), expected_hollow_vol)
  let solid_tb : ToroidalBend = {
    bend_radius_mm: 30.0,
    outer_diameter_mm: 12.0,
    inner_diameter_mm: 0.0,
    angle_deg: 45.0,
  }
  let solid = ToroidalBend::new(30.0, 12.0, 45.0)
  let step_solid = Design::new(name="torus-solid")
    .add(solid.with_name("solid"))
    .to_step_file()
  inspect(step_solid.split("CLOSED_SHELL(").count() - 1, content="1")
  inspect(step_solid.split("ADVANCED_FACE(").count() - 1, content="3")
  inspect(step_solid.split("TOROIDAL_SURFACE(").count() - 1, content="1")
  inspect(step_solid.split("PLANE(").count() - 1, content="2")
  let expected_solid_vol = @math.PI * 36.0 * 30.0 * (@math.PI / 4.0)
  assert_near(solid_tb.volume(), expected_solid_vol)
  let c = solid_tb.centroid()
  assert_true(c.0 > 0.0 && c.1 > 0.0 && c.2 == 0.0)
}

///|
test "ToroidalBend validation rejects invalid parameters" {
  let bad_radius : ToroidalBend = {
    bend_radius_mm: 8.0,
    outer_diameter_mm: 20.0,
    inner_diameter_mm: 0.0,
    angle_deg: 90.0,
  }
  let bad_bore : ToroidalBend = {
    bend_radius_mm: 25.0,
    outer_diameter_mm: 20.0,
    inner_diameter_mm: 20.0,
    angle_deg: 90.0,
  }
  let zero_angle : ToroidalBend = {
    bend_radius_mm: 25.0,
    outer_diameter_mm: 20.0,
    inner_diameter_mm: 0.0,
    angle_deg: 0.0,
  }
  let full_angle : ToroidalBend = {
    bend_radius_mm: 25.0,
    outer_diameter_mm: 20.0,
    inner_diameter_mm: 0.0,
    angle_deg: 360.0,
  }
  assert_false(bad_radius.validate())
  assert_false(bad_bore.validate())
  assert_false(zero_angle.validate())
  assert_false(full_angle.validate())
}
