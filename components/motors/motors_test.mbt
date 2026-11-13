///|
fn nema_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
test "NEMA17 frame table matches the mounting interface" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_true(nema_close(frame.frame_mm, 42.3))
  assert_true(nema_close(frame.bolt_spacing_mm, 31.0))
  assert_true(nema_close(frame.mounting_hole_diameter_mm, 3.384))
  assert_true(nema_close(frame.pilot_diameter_mm, 22.0))
  assert_true(nema_close(frame.shaft_diameter_mm, 5.0))
  let alias_frame = match @motors.nema_frame(" nema-17 ") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_eq(alias_frame.designation, "NEMA17")
  assert_true(@motors.nema_frame("NEMA99") is Err(_))
}

///|
test "NEMA17 motor envelope dimensions" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let part = match @motors.nema_stepper_motor(frame, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(nema_close(x0, -21.15))
  assert_true(nema_close(x1, 21.15))
  assert_true(nema_close(y0, -21.15))
  assert_true(nema_close(y1, 21.15))
  assert_true(nema_close(z0, 0.0))
  // 40 mm body + 3.384 mm pilot + 11.421 mm default shaft.
  assert_true(nema_close(z1, 54.805))
  assert_eq(part.layers().length(), 3)
  assert_true(part.features().modeled.contains("mounting-hole-pattern"))
  assert_true(part.features().modeled.contains("pilot-boss"))
}

///|
test "NEMA23 motor envelope dimensions and overrides" {
  let frame = match @motors.nema_frame("NEMA23") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let part = match
    @motors.nema_stepper_motor(
      frame,
      40.0,
      shaft_length_mm=20.0,
      shaft_diameter_mm=8.0,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(nema_close(x0, -28.2))
  assert_true(nema_close(x1, 28.2))
  assert_true(nema_close(z0, 0.0))
  assert_true(nema_close(z1, 64.512))
  let (bx0, bx1, by0, by1, _bz0, _bz1) = part.layers()[0].shape.bounding_box()
  assert_true(nema_close(bx0, -28.2))
  assert_true(nema_close(bx1, 28.2))
  assert_true(nema_close(by0, -28.2))
  assert_true(nema_close(by1, 28.2))
}

///|
test "NEMA motor rejects invalid parameters" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_true(@motors.nema_stepper_motor(frame, 0.0) is Err(_))
  assert_true(
    @motors.nema_stepper_motor(frame, 40.0, shaft_length_mm=0.0) is Err(_),
  )
  assert_true(
    @motors.nema_stepper_motor(frame, 40.0, shaft_diameter_mm=22.0) is Err(_),
  )
  assert_true(
    @motors.nema_stepper_motor(frame, 40.0, pilot_diameter_mm=50.0) is Err(_),
  )
  assert_true(@motors.nema_motor_by_designation("NEMA99", 40.0) is Err(_))
}
