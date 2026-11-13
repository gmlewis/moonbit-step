///|
fn has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn find_connector(
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
fn near_value(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "ISO 4762 screw exposes shaft, thread, and head connectors" {
  let screw = match @fasteners.iso4762_screw(@standards.MetricSize::M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(screw, "shaft"))
  assert_true(has_connector(screw, "thread-start"))
  assert_true(has_connector(screw, "head-bearing-face"))
  assert_true(has_connector(screw, "head-top"))
  let shaft = find_connector(screw, "shaft")
  assert_true(near_value(shaft.placement.trans.2, -20.0))
  assert_true(shaft.axis.2 < -0.99)
  assert_true(shaft.kind is @common.MateKind::CylindricalShaft)
  assert_true(shaft.gender is @common.MateGender::Male)
  match shaft.diameter_mm {
    Some(d) => assert_true(near_value(d, 4.0))
    None => fail("expected shaft diameter")
  }
  let face = find_connector(screw, "head-bearing-face")
  assert_true(face.kind is @common.MateKind::PlaneFace)
  assert_true(near_value(face.placement.trans.2, 0.0))
}

///|
test "ISO 4032 nut exposes a bore and two bearing faces" {
  let nut = match @fasteners.iso4032_nut(@standards.MetricSize::M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(nut, "bore"))
  assert_true(has_connector(nut, "bearing-face-bottom"))
  assert_true(has_connector(nut, "bearing-face-top"))
  let bore = find_connector(nut, "bore")
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(bore.gender is @common.MateGender::Female)
  match bore.diameter_mm {
    Some(d) => assert_true(near_value(d, 4.0))
    None => fail("expected bore diameter")
  }
  assert_true(find_connector(nut, "bearing-face-top").placement.trans.2 > 0.0)
}

///|
test "washers expose a bore and face frames" {
  let washer = match @fasteners.iso7089_washer(@standards.MetricSize::M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(washer, "bore"))
  assert_true(has_connector(washer, "face-bottom"))
  assert_true(has_connector(washer, "face-top"))
  assert_true(
    find_connector(washer, "face-top").placement.trans.2 >
    find_connector(washer, "face-bottom").placement.trans.2,
  )
}

///|
test "pins expose an end frame at each end" {
  let pin = match @fasteners.iso2338_pin(@standards.MetricSize::M5, 30.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let a = find_connector(pin, "shaft-a")
  let b = find_connector(pin, "shaft-b")
  assert_true(near_value(a.placement.trans.2, -15.0))
  assert_true(near_value(b.placement.trans.2, 15.0))
  assert_true(a.axis.2 < -0.99)
  assert_true(b.axis.2 > 0.99)
}

///|
test "threaded rods expose threaded ends" {
  let rod = match @fasteners.din976(@standards.MetricSize::M8, 200.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let a = find_connector(rod, "thread-end-a")
  let b = find_connector(rod, "thread-end-b")
  assert_true(a.kind is @common.MateKind::Threaded)
  assert_true(near_value(b.placement.trans.2, 200.0))
}

///|
test "set screws expose a point and a top face" {
  let screw = match @fasteners.din913(@standards.MetricSize::M3, 5.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(screw, "point"))
  assert_true(has_connector(screw, "top-face"))
  assert_true(
    near_value(find_connector(screw, "top-face").placement.trans.2, 5.0),
  )
}

///|
test "heat-set inserts and T-nuts expose thread interfaces" {
  let insert = match @fasteners.heat_set_insert_m3("short") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(insert, "thread"))
  assert_true(has_connector(insert, "insertion-end"))
  let thread = find_connector(insert, "thread")
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.gender is @common.MateGender::Female)
  let spec = match @fasteners.extrusion_tnut_spec("M3", slot_width_mm=5.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let tnut = match @fasteners.extrusion_tnut(spec) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_connector(tnut, "thread"))
  assert_true(has_connector(tnut, "slot-engagement"))
  assert_true(has_connector(tnut, "bearing-face"))
}
