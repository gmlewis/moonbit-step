///|
test "REV 15 mm extrusion reproduces the measured section" {
  let part = mbracket_ok(@profiles.rev_15mm_extrusion(length_mm=120.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 7.5).abs() < 1.0e-6)
  assert_true((x1 - 7.5).abs() < 1.0e-6)
  assert_true((y0 + 7.5).abs() < 1.0e-6)
  assert_true((y1 - 7.5).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 120.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  assert_eq(part.connectors().length(), 6)
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  // Measured outer 95.701 mm2 minus the Ø2.5 bore (4.9087), times 120 mm.
  assert_true((volume - 10895.1).abs() < 1.0)
}

///|
test "REV 15 mm family presets and end-tap connectors" {
  let family = mbracket_spec(@profiles.rev_15mm_family())
  assert_true(family.variant_names().contains("1000mm"))
  let part = mbracket_ok(family.build_variant("420mm"))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 420.0).abs() < 1.0e-6)
  let tap = match part.connector("end-tap-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(tap.kind is @common.MateKind::Threaded)
  assert_true((tap.diameter_mm.unwrap() - 2.54).abs() < 1.0e-6)
  assert_true(@profiles.rev_15mm_extrusion(length_mm=4.0) is Err(_))
}
