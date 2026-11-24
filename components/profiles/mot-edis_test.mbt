///|
test "MotEDIS 40x40 slot-8 profile is a nominal T-slot extrusion" {
  let part = mbracket_ok(@profiles.mot_edis_profile())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 20.0).abs() < 1.0e-6)
  assert_true((x1 - 20.0).abs() < 1.0e-6)
  assert_true((y0 + 20.0).abs() < 1.0e-6)
  assert_true((y1 - 20.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 100.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  // Two end datums plus four face slots.
  assert_eq(part.connectors().length(), 6)
  let slot = match part.connector("slot-top") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(slot.kind is @common.MateKind::ProfileSlot)
  assert_true((slot.diameter_mm.unwrap() - 8.0).abs() < 1.0e-6)
  // The four slots are a nominal difference; the kernel trims them.
  assert_true(part.to_design().diagnostics().any(fn(d) { d.is_nominal() }))
  assert_true(part.to_design().to_csg_step().contains("BOOLEAN_RESULT"))
}

///|
test "MotEDIS profile family length presets" {
  let family = mbracket_spec(@profiles.mot_edis_profile_family())
  assert_true(family.variant_names().contains("len-1000"))
  let part = mbracket_ok(family.build_variant("len-500"))
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 500.0).abs() < 1.0e-6)
  assert_true(@profiles.mot_edis_profile(length_mm=0.0) is Err(_))
}

///|
test "MotEDIS 20x20 slot-5 and 30x30 slot-6 sections" {
  let p20 = mbracket_ok(@profiles.mot_edis_profile_20x20())
  let (a0, a1, b0, b1, _c0, _c1) = p20.bounding_box()
  assert_true((a1 - a0 - 20.0).abs() < 1.0e-6)
  assert_true((b1 - b0 - 20.0).abs() < 1.0e-6)
  let p30 = mbracket_ok(@profiles.mot_edis_profile_30x30())
  let (d0, d1, e0, e1, _f0, _f1) = p30.bounding_box()
  assert_true((d1 - d0 - 30.0).abs() < 1.0e-6)
  assert_true((e1 - e0 - 30.0).abs() < 1.0e-6)
  assert_true(@profiles.mot_edis_section("50") is Err(_))
}

///|
test "MotEDIS slot-8 T-nut envelope" {
  let section = mbracket_spec(@profiles.mot_edis_section("40"))
  let part = mbracket_ok(@profiles.mot_edis_tnut(section, thread="M5"))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 16.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 15.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 7.5).abs() < 1.0e-6)
  assert_eq(part.connectors().length(), 4)
  let thread = match part.connector("thread") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true((thread.diameter_mm.unwrap() - 5.0).abs() < 1.0e-6)
  assert_true(@profiles.mot_edis_tnut(section, thread="M2") is Err(_))
}
