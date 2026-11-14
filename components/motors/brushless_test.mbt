///|
fn bl_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn bl_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "360KV brushless defaults match the owner-authored envelope" {
  let spec = @motors.brushless_motor_360kv_spec()
  assert_true(@motors.brushless_motor_spec(spec) is Ok(_))
  let part = bl_ok(@motors.brushless_motor_360kv())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  // Shaft from -2 to 21; the bell/lip radius is 25.
  assert_true(bl_close(x0, -2.0))
  assert_true(bl_close(x1, 21.0))
  assert_true(bl_close(y0, -25.0))
  assert_true(bl_close(y1, 25.0))
  assert_true(bl_close(z0, -25.0))
  assert_true(bl_close(z1, 25.0))
  assert_eq(part.layers().length(), 10)
  assert_true(part.layers().any(fn(l) { l.name == "bell-spoke-5" }))
  assert_true(part.features().modeled.contains("bell-windows"))
  assert_true(part.features().has_approximated("bell-window-corner-radius"))
  assert_true(part.features().omission_reason("kv-and-performance") is Some(_))
}

///|
test "360KV brushless exposes named mechanical connectors" {
  let part = bl_ok(@motors.brushless_motor_360kv())
  for name in ["shaft", "shaft-rear", "mount-face", "bell-face"] {
    assert_true(part.connector(name) is Ok(_))
  }
  for i in 1..<=4 {
    assert_true(part.connector("prop-hole-\{i}") is Ok(_))
    assert_true(part.connector("mount-hole-\{i}") is Ok(_))
  }
  let shaft = match part.connector("shaft") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(shaft.kind is @common.MateKind::CylindricalShaft)
  assert_true(bl_close(shaft.diameter_mm.unwrap(), 4.0))
  let mount = match part.connector("mount-face") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bl_close(mount.placement.trans.0, 18.0))
  assert_true(mount.kind is @common.MateKind::PlaneFace)
}

///|
test "brushless parameters can be overridden for a measured motor" {
  let spec : @motors.BrushlessMotorSpec = {
    ..@motors.brushless_motor_360kv_spec(),
    bell_outer_diameter_mm: 42.0,
    bell_wall_thickness_mm: 1.2,
    bell_face_outer_diameter_mm: 38.0,
    bell_face_thickness_mm: 3.0,
    bell_hub_diameter_mm: 15.0,
    window_inner_diameter_mm: 16.0,
    window_outer_diameter_mm: 35.0,
    prop_hole_circle_diameter_mm: 10.0,
    bell_lip_major_radius_mm: 20.0,
    stator_hub_diameter_mm: 24.0,
    stator_hub_start_mm: 16.0,
    shaft_diameter_mm: 3.0,
    shaft_rear_extension_mm: 3.0,
  }
  assert_true(@motors.brushless_motor_spec(spec) is Ok(_))
  let part = bl_ok(@motors.brushless_motor(spec))
  let (_x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true(bl_close(x1, 16.0 + 2.0 + 1.0))
  assert_true(bl_close(y0, -21.0))
  assert_true(bl_close(y1, 21.0))
}

///|
test "brushless validation rejects an impossible window layout" {
  let too_wide : @motors.BrushlessMotorSpec = {
    ..@motors.brushless_motor_360kv_spec(),
    window_outer_half_angle_deg: 40.0,
  }
  assert_true(@motors.brushless_motor_spec(too_wide) is Err(_))
  let bad_shaft : @motors.BrushlessMotorSpec = {
    ..@motors.brushless_motor_360kv_spec(),
    shaft_diameter_mm: 26.0,
  }
  assert_true(@motors.brushless_motor_spec(bad_shaft) is Err(_))
  let bad_face : @motors.BrushlessMotorSpec = {
    ..@motors.brushless_motor_360kv_spec(),
    bell_face_outer_diameter_mm: 50.0,
  }
  assert_true(@motors.brushless_motor_spec(bad_face) is Err(_))
}
