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

///|
test "every public profile builder family exposes a connector" {
  let builders : Array[(@common.Component, String)] = [
    (
      match @profiles.extrusion(@profiles.TSlotProfile::generic_2020(), 100.0) {
        Ok(c) => c
        Err(e) => abort(e.message())
      },
      "slot-x-plus",
    ),
    (
      match
        @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 100.0) {
        Ok(c) => c
        Err(e) => abort(e.message())
      },
      "slot-x-plus",
    ),
    (
      match @profiles.b_slot6_2020_extrusion(100.0) {
        Ok(c) => c
        Err(e) => abort(e.message())
      },
      "slot-y-minus",
    ),
    (
      match @profiles.vslot_corner_bracket() {
        Ok(c) => c
        Err(e) => abort(e.message())
      },
      "base-face",
    ),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !has_profile_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}
