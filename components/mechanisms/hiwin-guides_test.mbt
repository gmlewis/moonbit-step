///|
fn[T] hiwin_spec(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "Hiwin HGR15 rail matches the catalogue section and hole pitch" {
  let part = mech_ok(@mechanisms.hiwin_hgr_rail(size="HGR15", length_mm=400.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(x0.abs() < 1.0e-6)
  assert_true((x1 - 400.0).abs() < 1.0e-6)
  assert_true((y0 + 7.5).abs() < 1.0e-6)
  assert_true((y1 - 7.5).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 15.0).abs() < 1.0e-6)
  // 7 holes at 20, 80, ..., 380 mm, plus the base and top faces.
  assert_eq(part.connectors().length(), 9)
  let hole = match part.connector("mount-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((hole.diameter_mm.unwrap() - 7.5).abs() < 1.0e-6)
  assert_true((hole.placement.trans.0 - 20.0).abs() < 1.0e-6)
  let last = match part.connector("mount-hole-7") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((last.placement.trans.0 - 380.0).abs() < 1.0e-6)
}

///|
test "Hiwin HGR20 rail uses the 20 x 17.5 section" {
  let part = mech_ok(@mechanisms.hiwin_hgr_rail(size="HGR20", length_mm=340.0))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 17.5).abs() < 1.0e-6)
  // (340 - 40) / 60 = 5 intervals, so 6 holes.
  assert_eq(part.connectors().length(), 8)
  assert_true(@mechanisms.hiwin_hgr_rail(size="HGR10") is Err(_))
  assert_true(
    @mechanisms.hiwin_hgr_rail(size="HGR15", length_mm=30.0) is Err(_),
  )
}

///|
test "Hiwin HGH15CA carriage has the 26 x 26 bolt pattern" {
  let part = mech_ok(@mechanisms.hiwin_hgh_block(size="HGH15CA"))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 30.7).abs() < 1.0e-6)
  assert_true((x1 - 30.7).abs() < 1.0e-6)
  assert_true((y0 + 17.0).abs() < 1.0e-6)
  assert_true((y1 - 17.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 28.0).abs() < 1.0e-6)
  assert_eq(part.connectors().length(), 6)
  let hole = match part.connector("mount-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(hole.kind is @common.MateKind::Threaded)
  assert_true((hole.placement.trans.0 + 13.0).abs() < 1.0e-6)
  assert_true((hole.placement.trans.1 + 13.0).abs() < 1.0e-6)
}

///|
test "Hiwin rail and block families expose the catalogue presets" {
  let rail = hiwin_spec(@mechanisms.hiwin_rail_family())
  assert_true(rail.variant_names().contains("400mm"))
  let part = mech_ok(rail.build_variant("400mm"))
  let (_x0, x1, _y0, _y1, _z0, _z1) = part.bounding_box()
  assert_true((x1 - 400.0).abs() < 1.0e-6)
  let block = hiwin_spec(@mechanisms.hiwin_block_family())
  assert_true(block.variant_names().contains("HGH20CA"))
}
