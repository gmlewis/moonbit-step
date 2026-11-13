///|
fn drive_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn drive_connector(
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
fn drive_volume(part : @common.Component) -> Double {
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  volume
}

///|
test "rigid coupling is an analytic sleeve" {
  let part = match @motion.rigid_coupling(8.0, 16.0, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 16.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 16.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 20.0).abs() < 1.0e-6)
  assert_true((drive_volume(part) - 3015.929).abs() < 0.2)
  for name in ["bore-a", "bore-b", "outer-seat", "face-a", "face-b"] {
    if !drive_has(part, name) {
      abort("rigid coupling is missing connector " + name)
    }
  }
  let bore = drive_connector(part, "bore-a")
  match bore.diameter_mm {
    Some(d) => assert_true((d - 8.0).abs() < 1.0e-9)
    None => fail("expected the coupling bore diameter")
  }
  assert_true(bore.gender is @common.MateGender::Female)
}

///|
test "rigid coupling rejects an oversized bore" {
  assert_true(@motion.rigid_coupling(16.0, 16.0, 20.0) is Err(_))
  assert_true(@motion.rigid_coupling(8.0, 16.0, 0.0) is Err(_))
}

///|
test "flanged bearing housing has a seat, flange, and bolt circle" {
  let part = match @motion.flanged_bearing_housing(22.0, 7.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 46.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 46.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 11.0).abs() < 1.0e-6)
  assert_true(part.layers().length() == 2)
  assert_true((drive_volume(part) - 6396.282).abs() < 0.2)
  let seat = drive_connector(part, "bearing-seat")
  match seat.diameter_mm {
    Some(d) => assert_true((d - 22.0).abs() < 1.0e-9)
    None => fail("expected the bearing seat diameter")
  }
  assert_true(seat.fit is @cad.Fit::Nominal)
  for i in 1..<5 {
    let name = "bolt-hole-\{i}"
    if !drive_has(part, name) {
      abort("flanged housing is missing connector " + name)
    }
  }
  let bolt = drive_connector(part, "bolt-hole-1")
  assert_true((bolt.placement.trans.0 - 18.0).abs() < 1.0e-9)
  assert_true(bolt.placement.trans.1.abs() < 1.0e-9)
  assert_true(bolt.kind is @common.MateKind::CylindricalBore)
}

///|
test "flanged bearing housing records the declared seat fit" {
  let free = match @motion.flanged_bearing_housing(22.0, 7.0, fit_mm=0.1) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(drive_connector(free, "bearing-seat").fit is @cad.Fit::Free)
  let press = match @motion.flanged_bearing_housing(22.0, 7.0, fit_mm=-0.1) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(drive_connector(press, "bearing-seat").fit is @cad.Fit::Press)
}

///|
test "flanged bearing housing rejects impossible flanges" {
  assert_true(
    @motion.flanged_bearing_housing(22.0, 7.0, flange_diameter_mm=26.0)
    is Err(_),
  )
  assert_true(
    @motion.flanged_bearing_housing(22.0, 7.0, bolt_circle_diameter_mm=24.0)
    is Err(_),
  )
  assert_true(
    @motion.flanged_bearing_housing(22.0, 7.0, bolt_circle_diameter_mm=44.0)
    is Err(_),
  )
  assert_true(
    @motion.flanged_bearing_housing(22.0, 7.0, bolt_count=0) is Err(_),
  )
  assert_true(
    @motion.flanged_bearing_housing(22.0, 7.0, bolt_count=24) is Err(_),
  )
}
