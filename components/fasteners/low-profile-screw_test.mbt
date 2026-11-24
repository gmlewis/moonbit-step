///|
test "Maker Store M5 low-profile screw has a 1.5 mm head" {
  let part = ok_fastener(@fasteners.low_profile_screw(length_mm=16.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 4.45).abs() < 1.0e-6)
  assert_true((x1 - 4.45).abs() < 1.0e-6)
  assert_true((y0 + 4.45).abs() < 1.0e-6)
  assert_true((y1 - 4.45).abs() < 1.0e-6)
  assert_true((z0 + 16.0).abs() < 1.0e-6)
  assert_true((z1 - 1.5).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  assert_eq(part.connectors().length(), 2)
  let thread = match part.connector("thread") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.gender is @common.MateGender::Male)
  assert_true((thread.diameter_mm.unwrap() - 5.0).abs() < 1.0e-6)
  let seat = match part.connector("head-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((seat.diameter_mm.unwrap() - 8.9).abs() < 1.0e-6)
}

///|
test "Maker Store M5 low-profile screw family has the 16 published lengths" {
  let family = match @fasteners.low_profile_screw_family() {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let names = family.variant_names()
  assert_eq(names.length(), 16)
  assert_true(names.contains("6mm"))
  assert_true(names.contains("65mm"))
  let part = ok_fastener(family.build_variant("65mm"))
  let (_x0, _x1, _y0, _y1, z0, _z1) = part.bounding_box()
  assert_true((z0 + 65.0).abs() < 1.0e-6)
}
