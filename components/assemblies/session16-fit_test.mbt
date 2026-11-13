///|
fn session16_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
test "a 608 bearing seats in the flanged housing by named connectors" {
  let housing = match @motion.flanged_bearing_housing(22.0, 7.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let bearing = match @motion.bearing_by_designation("608") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="bearing-seat",
    child="outer-seat",
    description="608 outer ring in the flanged bearing housing seat",
  )
  let assembly = @assemblies.Assembly::new(name="flanged-housing-608").add(
    housing,
    instance_name="housing",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("housing", bearing, pair, instance_name="bearing") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(session16_close(alignment.nominal_diameter_gap_mm(), 0.0, 1.0e-9))
  assert_true(alignment.insertion_anti_parallel)
}

///|
test "a rigid coupling bore receives a shaft by named connectors" {
  let coupling = match @motion.rigid_coupling(8.0, 16.0, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let shaft = match @motion.shaft(8.0, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="bore-a",
    child="shaft-a",
    description="8 mm shaft entering the rigid coupling bore",
  )
  let assembly = @assemblies.Assembly::new(name="coupling-shaft").add(
    coupling,
    instance_name="coupling",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("coupling", shaft, pair, instance_name="shaft") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(session16_close(alignment.nominal_diameter_gap_mm(), 0.0, 1.0e-9))
  assert_true(alignment.insertion_anti_parallel)
}

///|
test "a channel nut clears the opening and bears on the lips" {
  let section = @profiles.ChannelSection::p1000()
  let channel = match @profiles.strut_channel(section, 500.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let nut = match @profiles.channel_nut(section, 5.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let slot = match channel.connector("slot-open") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let engagement = match nut.connector("slot-engagement") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(slot.kind.to_string(), "profile-slot")
  assert_eq(engagement.kind.to_string(), "profile-slot")
  let opening = slot.diameter_mm.unwrap()
  let nut_width = engagement.diameter_mm.unwrap()
  assert_true(session16_close(opening, 22.2, 1.0e-12))
  assert_true(session16_close(nut_width, 20.0, 1.0e-12))
  assert_true(session16_close(opening - nut_width, 2.2, 1.0e-12))
  // The nut length exceeds the opening so it bears on the lips, and its
  // thickness stays inside the cavity.
  let nut_length = match nut.metadata().length_mm {
    Some(l) => l
    None => fail("expected the channel nut length")
  }
  assert_true(nut_length > opening)
  assert_true(6.0 < section.cavity_height())
}
