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

///|
fn ok_motor(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn[T] ok_motor_spec(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "every public motor builder family exposes a connector" {
  let frame = ok_motor_spec(@motors.nema_frame("NEMA17"))
  let builders : Array[(@common.Component, String)] = [
    (ok_motor(@motors.nema_stepper_motor(frame, 40.0)), "mounting-face"),
    (ok_motor(@motors.nema_motor_by_designation("NEMA17", 40.0)), "shaft"),
    (
      ok_motor(@motors.nema_mounting_plate(frame, 50.0, 50.0, 5.0)),
      "pilot-bore",
    ),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !has_motor_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}
