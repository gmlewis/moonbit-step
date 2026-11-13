///|
fn has_motor_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn motor_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
test "NEMA motor exposes mount, pilot, shaft, and four bolt holes" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let part = match @motors.nema_stepper_motor(frame, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_motor_connector(part, "mounting-face"))
  assert_true(has_motor_connector(part, "mounting-pattern"))
  assert_true(has_motor_connector(part, "pilot"))
  assert_true(has_motor_connector(part, "shaft"))
  assert_true(has_motor_connector(part, "rear-face"))
  for i in 1..<=4 {
    assert_true(has_motor_connector(part, "bolt-hole-\{i}"))
  }
  let pilot = motor_connector(part, "pilot")
  assert_true((pilot.placement.trans.2 - 40.0).abs() < 1.0e-9)
  let shaft = motor_connector(part, "shaft")
  assert_true(shaft.placement.trans.2 > pilot.placement.trans.2)
  let hole = motor_connector(part, "bolt-hole-1")
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
}
