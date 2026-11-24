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
  assert_eq(part.layers().length(), 1)
  // Four faces plus eight bearing seats on the base and on each leg.
  assert_eq(part.connectors().length(), 4 + 3 * 8)
  let bearing = match part.connector("bearing-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bearing.kind is @common.MateKind::CylindricalBore)
  assert_true((bearing.diameter_mm.unwrap() - 14.0).abs() < 1.0e-6)
  assert_true((bearing.placement.trans.1 + 84.0).abs() < 1.0e-6)
  let leg = match part.connector("leg-hole-right-8") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((leg.placement.trans.1 - 84.0).abs() < 1.0e-6)
  assert_true((leg.placement.trans.0 - 24.0).abs() < 1.0e-6)
  assert_true((leg.placement.trans.2 - 24.0).abs() < 1.0e-6)
}

///|
test "goBILDA U-channel pattern volume matches the measured 8-hole part" {
  let part = gobilda_ok(@gobilda.gobilda_u_channel())
  let mut nominal = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => nominal += v
      Err(e) => abort(e.message())
    }
  }
  // The nominal union sums the three plates; the evaluated engine unions them,
  // removing the two 2.5 x 2.5 x 216 mm corner overlaps. The result agrees with
  // the measured vendor solid (53 320.47 mm3) to better than 0.01 %.
  let corner_overlap = 2.0 * 2.5 * 2.5 * 216.0
  let union = nominal - corner_overlap
  assert_true((union - 53324.124).abs() < 1.0e-3)
  assert_true((union - 53320.471).abs() < 0.0001 * 53320.471)
}

///|
test "goBILDA 1-hole U-channel is 48 mm long" {
  let part = gobilda_ok(@gobilda.gobilda_u_channel(holes=1))
  let (_x0, _x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((y1 - y0 - 48.0).abs() < 1.0e-6)
  // One interior station carries a bearing seat on the base and each leg.
  assert_eq(part.connectors().length(), 4 + 3)
}

///|
test "goBILDA U-channel family presets" {
  let family = gobilda_spec(@gobilda.gobilda_u_channel_family())
  let names = family.variant_names()
  assert_true(names.contains("8-hole"))
  assert_true(names.contains("49-hole"))
  let part = gobilda_ok(family.build_variant("8-hole"))
  let (_x0, _x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((y1 - y0 - 216.0).abs() < 1.0e-6)
  assert_true(@gobilda.gobilda_u_channel(holes=0) is Err(_))
}
