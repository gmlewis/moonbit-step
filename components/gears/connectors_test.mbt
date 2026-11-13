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
