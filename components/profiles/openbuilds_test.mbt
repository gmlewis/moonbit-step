///|
test "OpenBuilds C-Beam gantry plate SKU 970 envelope" {
  let part = mbracket_ok(@profiles.openbuilds_cbeam_gantry_plate())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 38.75).abs() < 1.0e-6)
  assert_true((x1 - 38.75).abs() < 1.0e-6)
  assert_true((y0 + 38.75).abs() < 1.0e-6)
  assert_true((y1 - 38.75).abs() < 1.0e-6)
  assert_true((z0 + 3.0).abs() < 1.0e-6)
  assert_true((z1 - 3.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  // Two faces plus eight tapped holes.
  assert_eq(part.connectors().length(), 10)
  let hole = match part.connector("hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(hole.kind is @common.MateKind::Threaded)
  assert_true((hole.placement.trans.0 + 20.0).abs() < 1.0e-6)
  assert_true((hole.placement.trans.1 + 20.0).abs() < 1.0e-6)
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  let expected = (77.5 * 77.5 - 8.0 * @math.PI * 2.1 * 2.1) * 6.0
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
  let family = mbracket_spec(@profiles.openbuilds_gantry_plate_family())
  assert_true(family.variant_names().contains("sku-970"))
}
