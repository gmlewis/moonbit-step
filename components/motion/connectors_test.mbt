///|
fn motion_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn motion_connector(
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
fn motion_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "plain shaft exposes end frames" {
  let part = match @motion.shaft(10.0, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let a = motion_connector(part, "shaft-a")
  let b = motion_connector(part, "shaft-b")
  assert_true(motion_near(a.placement.trans.2, 0.0))
  assert_true(motion_near(b.placement.trans.2, 40.0))
  assert_true(a.kind is @common.MateKind::CylindricalShaft)
}

///|
test "spacer and bushing expose a bore and outer seat" {
  let part = match @motion.spacer(10.0, 5.0, 12.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "bore"))
  assert_true(motion_has_connector(part, "outer-seat"))
  assert_true(motion_has_connector(part, "face-positive"))
  let bore = motion_connector(part, "bore")
  assert_true(bore.gender is @common.MateGender::Female)
}

///|
test "bearing exposes bore, outer seat, and faces" {
  let size = @motion.bearing_size("608") // 8 x 22 x 7
  let part = match size {
    Ok(s) =>
      match @motion.bearing(s, detail=@common.DetailLevel::Simplified) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
    Err(e) => abort(e.message())
  }
  let bore = motion_connector(part, "bore")
  match bore.diameter_mm {
    Some(d) => assert_true(motion_near(d, 8.0))
    None => fail("expected bearing bore diameter")
  }
  let seat = motion_connector(part, "outer-seat")
  match seat.diameter_mm {
    Some(d) => assert_true(motion_near(d, 22.0))
    None => fail("expected bearing outer diameter")
  }
  assert_true(
    motion_near(motion_connector(part, "face-positive").placement.trans.2, 7.0),
  )
}

///|
test "keyed shaft exposes ends and a keyway datum" {
  let part = match @motion.keyed_shaft(20.0, 40.0, 6.0, 3.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "shaft-a"))
  assert_true(motion_has_connector(part, "shaft-b"))
  let datum = motion_connector(part, "keyway-datum")
  assert_true(datum.kind is @common.MateKind::Datum)
  assert_true(datum.axis.1 > 0.99)
}

///|
test "compression spring exposes end datums" {
  let part = match @motion.compression_spring(20.0, 2.0, 40.0, 6) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "end-a"))
  assert_true(motion_has_connector(part, "end-b"))
}
