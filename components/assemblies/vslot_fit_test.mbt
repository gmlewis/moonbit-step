///|
fn vslot_fit_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "a 625 bearing seats in a V-wheel pocket by named connectors" {
  let wheel = match @motion.v_wheel(@motion.VWheelSpec::openbuilds_solid_v()) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let bearing = match @motion.bearing_by_designation("625") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="bearing-seat-a",
    child="outer-seat",
    description="625 bearing outer ring in the V-wheel bearing pocket",
  )
  let assembly = @assemblies.Assembly::new(name="vslot-wheel-bearing").add(
    wheel,
    instance_name="wheel",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("wheel", bearing, pair, instance_name="bearing") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(vslot_fit_close(alignment.nominal_diameter_gap_mm(), 0.0, 1.0e-9))
  assert_true(alignment.insertion_anti_parallel)
}

///|
test "a V-Slot T-nut fits inside the slot envelope" {
  let profile = @profiles.VSlotProfile::vslot_2020()
  let nut = @fasteners.SlotTNutSpec::openbuilds_m5()
  // The nut's width must pass the neck; its length must fit the cavity; its
  // height must stay under the lip.
  assert_true(nut.width_mm <= profile.slot_neck_mm)
  assert_true(nut.length_mm <= profile.cavity_width_mm)
  assert_true(
    nut.height_mm <= profile.lip_thickness_mm + profile.cavity_depth_mm,
  )
  // The clearance is explicit: the nut is narrower than the neck by 0.25 mm.
  let clearance = profile.slot_neck_mm - nut.width_mm
  assert_true(vslot_fit_close(clearance, 0.25, 1.0e-9))
}

///|
test "a V-Slot T-nut and extrusion expose matching named interfaces" {
  let extrusion = match
    @profiles.vslot_extrusion(@profiles.VSlotProfile::vslot_2020(), 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let nut = match
    @fasteners.vslot_t_nut(@fasteners.SlotTNutSpec::openbuilds_m5()) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let slot = match extrusion.connector("slot-x-plus") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let engagement = match nut.connector("slot-engagement") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(slot.kind.to_string(), "profile-slot")
  assert_eq(engagement.kind.to_string(), "profile-slot")
  assert_true(vslot_fit_close(slot.diameter_mm.unwrap(), 6.25, 1.0e-12))
  assert_true(vslot_fit_close(engagement.diameter_mm.unwrap(), 6.0, 1.0e-12))
}

///|
test "a V-wheel groove straddles the V-Slot lips" {
  let profile = @profiles.VSlotProfile::vslot_2020()
  let wheel = @motion.VWheelSpec::openbuilds_solid_v()
  // The groove's minor diameter is well outside the 9.16 mm V mouth, so the
  // flanks ride on the lips rather than dropping into the cavity.
  assert_true(wheel.groove_min_diameter_mm > profile.slot_mouth_mm)
  // The groove is 3.2 mm deep and the lip band is 1.8 mm, leaving clearance.
  let groove_depth = (wheel.outer_diameter_mm - wheel.groove_min_diameter_mm) /
    2.0
  assert_true(groove_depth > profile.lip_thickness_mm)
}
