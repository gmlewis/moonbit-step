///|
test "goBILDA Sonic hub envelope matches Ø32 x 10 mm with a 16 mm pattern" {
  let part = gobilda_ok(@gobilda.gobilda_sonic_hub())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 16.0).abs() < 1.0e-6)
  assert_true((x1 - 16.0).abs() < 1.0e-6)
  assert_true((y0 + 16.0).abs() < 1.0e-6)
  assert_true((y1 - 16.0).abs() < 1.0e-6)
  assert_true((z0 + 5.0).abs() < 1.0e-6)
  assert_true((z1 - 5.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 2)
  // Four face frames plus four bolt holes (the hex bore is one of the faces).
  assert_eq(part.connectors().length(), 8)
  let bore = match part.connector("rex-bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((bore.diameter_mm.unwrap() - 7.0).abs() < 1.0e-6)
  let bolt = match part.connector("bolt-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((bolt.diameter_mm.unwrap() - 4.0).abs() < 1.0e-6)
  assert_true((bolt.placement.trans.0 + 8.0).abs() < 1.0e-6)
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  let hex_area = 2.0 * 3.0.sqrt() * 3.5 * 3.5
  let body = @math.PI * 16.0 * 16.0 * 8.0 -
    hex_area * 8.0 -
    4.0 * @math.PI * 2.0 * 2.0 * 8.0
  let boss = @math.PI * 7.0 * 7.0 * 2.0 - hex_area * 2.0
  let expected = body + boss
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
}

///|
test "goBILDA Sonic hub family preset" {
  let family = gobilda_spec(@gobilda.gobilda_sonic_hub_family())
  assert_true(family.variant_names().contains("1309-8mm-rex"))
  let part = gobilda_ok(family.build_variant("1309-8mm-rex"))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 5.0).abs() < 1.0e-6)
}

///|
test "goBILDA Sonic hub rejects a bore that does not fit the boss" {
  assert_true(@gobilda.gobilda_sonic_hub(bore_flats_mm=14.0) is Err(_))
}
