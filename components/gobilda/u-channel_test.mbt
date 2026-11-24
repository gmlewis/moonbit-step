///|
test "goBILDA U-channel matches the 48 x 48 x 216 envelope" {
  let part = gobilda_ok(@gobilda.gobilda_u_channel())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 24.0).abs() < 1.0e-6)
  assert_true((x1 - 24.0).abs() < 1.0e-6)
  assert_true((y0 + 108.0).abs() < 1.0e-6)
  assert_true((y1 - 108.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 48.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 3)
  // Two faces plus eight bearing seats.
  assert_eq(part.connectors().length(), 10)
  let bearing = match part.connector("bearing-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bearing.kind is @common.MateKind::CylindricalBore)
  assert_true((bearing.diameter_mm.unwrap() - 14.0).abs() < 1.0e-6)
  assert_true((bearing.placement.trans.1 + 84.0).abs() < 1.0e-6)
  // Exact U-section area (48x48 outside, 43x45.5 inside) times length, minus
  // 88 base grid holes and 8 bearing holes through the 2.5 mm base.
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  let section = 48.0 * 48.0 - 43.0 * 45.5
  let grid = 88.0 * @math.PI * 2.0 * 2.0 * 2.5
  let bearings = 8.0 * @math.PI * 7.0 * 7.0 * 2.5
  let expected = section * 216.0 - grid - bearings
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
}

///|
test "goBILDA 1-hole U-channel is 48 mm long" {
  let part = gobilda_ok(@gobilda.gobilda_u_channel(holes=1))
  let (_x0, _x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((y1 - y0 - 48.0).abs() < 1.0e-6)
  assert_eq(part.connectors().length(), 3)
}

///|
test "goBILDA U-channel family presets" {
  let family = gobilda_spec(@gobilda.gobilda_u_channel_family())
  let names = family.variant_names()
  assert_true(names.contains("8-hole"))
  assert_true(names.contains("13-hole"))
  let part = gobilda_ok(family.build_variant("8-hole"))
  let (_x0, _x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((y1 - y0 - 216.0).abs() < 1.0e-6)
  assert_true(@gobilda.gobilda_u_channel(holes=0) is Err(_))
}
