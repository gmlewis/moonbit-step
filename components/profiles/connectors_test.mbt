///|
fn has_profile_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "extrusion exposes four face slots, two ends, and a core-bore datum" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let part = match @profiles.extrusion(profile, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_profile_connector(part, "slot-x-plus"))
  assert_true(has_profile_connector(part, "slot-x-minus"))
  assert_true(has_profile_connector(part, "slot-y-plus"))
  assert_true(has_profile_connector(part, "slot-y-minus"))
  assert_true(has_profile_connector(part, "end-a"))
  assert_true(has_profile_connector(part, "end-b"))
  assert_true(has_profile_connector(part, "core-bore"))
}

///|
test "V-slot-style vendor extrusion also carries face connectors" {
  let part = match @profiles.b_slot6_2020_extrusion(50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_profile_connector(part, "slot-x-plus"))
  assert_true(has_profile_connector(part, "end-b"))
}
