///|
test "REV 45 mm U-channel reproduces the measured section" {
  let part = mbracket_ok(@profiles.rev_45mm_uchannel(length_mm=440.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 22.5).abs() < 1.0e-6)
  assert_true((x1 - 22.5).abs() < 1.0e-6)
  assert_true((y0 + 22.5).abs() < 1.0e-6)
  assert_true((y1 - 22.5).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 440.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  assert_eq(part.connectors().length(), 4)
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  // Measured section 339.855 mm2, times 440 mm.
  assert_true((volume - 149536.3).abs() < 2.0)
}

///|
test "REV 45 mm family presets" {
  let family = mbracket_spec(@profiles.rev_45mm_family())
  assert_true(family.variant_names().contains("1000mm"))
  let part = mbracket_ok(family.build_variant("152mm"))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 152.0).abs() < 1.0e-6)
  assert_true(@profiles.rev_45mm_uchannel(length_mm=4.0) is Err(_))
}
