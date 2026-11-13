///|
fn vslot_spacer_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn vslot_spacer_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn vslot_spacer_connector(
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
test "ordinary V-Slot spacer is the published 10 x 5 x 6 boundary" {
  let part = match @motion.vslot_spacer() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(vslot_spacer_close(x1 - x0, 10.0, 1.0e-6))
  assert_true(vslot_spacer_close(y1 - y0, 10.0, 1.0e-6))
  assert_true(vslot_spacer_close(z0, 0.0, 1.0e-6))
  assert_true(vslot_spacer_close(z1, 6.0, 1.0e-6))
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // pi * (5^2 - 2.5^2) * 6 = 353.43 mm^3 as one analytic annulus.
  assert_true(vslot_spacer_close(volume, 353.429, 0.01))
  assert_true(vslot_spacer_has(part, "bore"))
  assert_true(vslot_spacer_has(part, "outer-seat"))
  match vslot_spacer_connector(part, "bore").diameter_mm {
    Some(d) => assert_true(vslot_spacer_close(d, 5.0, 1.0e-9))
    None => fail("expected the spacer bore")
  }
}

///|
test "eccentric V-Slot spacer carries the offset bore and 7.11 mm pilot" {
  let part = match @motion.vslot_eccentric_spacer() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(vslot_spacer_close(x0, -5.0, 1.0e-6))
  assert_true(vslot_spacer_close(x1, 5.0, 1.0e-6))
  assert_true(vslot_spacer_close(y1 - y0, 11.547005, 1.0e-4))
  assert_true(vslot_spacer_close(z0, -6.0, 1.0e-6))
  assert_true(vslot_spacer_close(z1, 2.5, 1.0e-6))
  let bore = vslot_spacer_connector(part, "bore")
  assert_true(vslot_spacer_close(bore.placement.trans.0, 0.79, 1.0e-9))
  assert_true(vslot_spacer_close(bore.placement.trans.2, -6.0, 1.0e-9))
  match bore.diameter_mm {
    Some(d) => assert_true(vslot_spacer_close(d, 5.0, 1.0e-9))
    None => fail("expected the eccentric bore")
  }
  let pilot = vslot_spacer_connector(part, "pilot")
  assert_true(pilot.kind is @common.MateKind::CylindricalShaft)
  match pilot.diameter_mm {
    Some(d) => assert_true(vslot_spacer_close(d, 7.11, 1.0e-9))
    None => fail("expected the pilot diameter")
  }
  assert_true(vslot_spacer_has(part, "seat-face"))
  assert_true(vslot_spacer_has(part, "hex-face"))
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true(vslot_spacer_close(volume, 451.98, 0.05))
}

///|
test "eccentric V-Slot spacer rejects a bore that breaks the wall" {
  assert_true(@motion.vslot_eccentric_spacer(eccentricity_mm=2.0) is Err(_))
  assert_true(@motion.vslot_eccentric_spacer(pilot_diameter_mm=10.0) is Err(_))
  assert_true(@motion.vslot_eccentric_spacer(bore_diameter_mm=0.0) is Err(_))
}
