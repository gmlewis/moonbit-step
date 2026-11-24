///|
test "goBILDA Sonic hub matches the measured 1309 envelope" {
  let part = gobilda_ok(@gobilda.gobilda_sonic_hub())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 12.686292).abs() < 1.0e-4)
  assert_true((x1 - 12.686292).abs() < 1.0e-4)
  assert_true(y0 > -16.1 && y1 < 16.1)
  assert_true((y1 - y0 - 32.0).abs() < 0.2)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 10.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 3)
  // Two faces, the hex bore, four tapped holes and two clamp screws.
  assert_eq(part.connectors().length(), 3 + 4 + 2)
  let bore = match part.connector("rex-bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((bore.diameter_mm.unwrap() - 7.0).abs() < 1.0e-6)
  let bolt = match part.connector("bolt-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bolt.kind is @common.MateKind::Threaded)
  assert_true((bolt.placement.trans.0 + 8.0).abs() < 1.0e-6)
  assert_true((bolt.placement.trans.1 + 8.0).abs() < 1.0e-6)
  let screw = match part.connector("clamp-screw-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(screw.kind is @common.MateKind::Threaded)
  assert_true((screw.placement.trans.2 - 4.0).abs() < 1.0e-6)
}

///|
test "goBILDA Sonic hub is a measured boolean design" {
  let part = gobilda_ok(@gobilda.gobilda_sonic_hub())
  // The clamp-screw bores are a real difference; the evaluated export trims
  // and unions the three layers into one solid.
  let design = part.to_design()
  assert_true(design.to_csg_step().contains("BOOLEAN_RESULT"))
  let flat = part.to_step()
  assert_true(flat.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
}

///|
test "goBILDA Sonic hub family preset" {
  let family = gobilda_spec(@gobilda.gobilda_sonic_hub_family())
  assert_true(family.variant_names().contains("1309-8mm-rex"))
  let part = gobilda_ok(family.build_variant("1309-8mm-rex"))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 10.0).abs() < 1.0e-6)
}

///|
test "goBILDA Sonic hub rejects a bore that does not fit the boss" {
  assert_true(@gobilda.gobilda_sonic_hub(bore_flats_mm=14.0) is Err(_))
}
