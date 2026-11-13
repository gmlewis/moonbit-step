///|
fn has_gear_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "spur gear exposes a bore, pitch datum, and two faces" {
  let params = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let gear = match @gears.spur_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_gear_connector(gear, "bore"))
  assert_true(has_gear_connector(gear, "pitch-plane"))
  assert_true(has_gear_connector(gear, "face-negative"))
  assert_true(has_gear_connector(gear, "face-positive"))
}

///|
fn ok_gear(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "every public gear builder family exposes a connector" {
  let params = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let builders : Array[(@common.Component, String)] = [
    (ok_gear(@gears.spur_gear(params)), "pitch-plane"),
    (ok_gear(@gears.spur_gear_envelope(params)), "pitch-plane"),
    (ok_gear(@gears.internal_ring_gear(2.0, 40, 10.0)), "pitch-plane"),
    (ok_gear(@gears.internal_ring_gear_exact(2.0, 40, 10.0)), "pitch-plane"),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !has_gear_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}
