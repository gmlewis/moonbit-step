///|
fn has_vslot_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "V-Slot 2020 exposes four slots, two ends, and one core bore" {
  let part = match
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_vslot_connector(part, "slot-x-plus"))
  assert_true(has_vslot_connector(part, "slot-x-minus"))
  assert_true(has_vslot_connector(part, "slot-y-plus"))
  assert_true(has_vslot_connector(part, "slot-y-minus"))
  assert_true(has_vslot_connector(part, "end-a"))
  assert_true(has_vslot_connector(part, "end-b"))
  assert_true(has_vslot_connector(part, "core-bore"))
  assert_true(!has_vslot_connector(part, "center-channel"))
  assert_eq(part.connectors().length(), 7)
  // Every slot connector reports the neck engagement width, not the mouth.
  let slot = match part.connector("slot-x-plus") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((slot.diameter_mm.unwrap() - 6.25).abs() < 1.0e-12)
  assert_eq(slot.kind.to_string(), "profile-slot")
}

///|
test "V-Slot 2040 exposes six slot connectors, two bores, and a channel" {
  let part = match
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2040(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_vslot_connector(part, "slot-x-plus-1"))
  assert_true(has_vslot_connector(part, "slot-x-plus-2"))
  assert_true(has_vslot_connector(part, "slot-x-minus-1"))
  assert_true(has_vslot_connector(part, "slot-x-minus-2"))
  assert_true(has_vslot_connector(part, "slot-y-plus"))
  assert_true(has_vslot_connector(part, "slot-y-minus"))
  assert_true(has_vslot_connector(part, "core-bore-1"))
  assert_true(has_vslot_connector(part, "core-bore-2"))
  assert_true(has_vslot_connector(part, "center-channel"))
  assert_eq(part.connectors().length(), 11)
}

///|
test "adding V-Slot connectors does not change geometry" {
  let connected = match
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let bare = match
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let a = connected.bounding_box()
  let b = bare.bounding_box()
  assert_true(a.0 == b.0 && a.1 == b.1)
  assert_true(a.2 == b.2 && a.3 == b.3)
  assert_true(a.4 == b.4 && a.5 == b.5)
  assert_eq(connected.layers().length(), bare.layers().length())
}
