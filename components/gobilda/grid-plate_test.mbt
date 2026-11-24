///|
fn gobilda_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn[T] gobilda_spec(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "goBILDA 5x5 grid plate matches the 8 mm pattern" {
  let part = gobilda_ok(@gobilda.gobilda_grid_plate())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 20.0).abs() < 1.0e-6)
  assert_true((x1 - 20.0).abs() < 1.0e-6)
  assert_true((y0 + 20.0).abs() < 1.0e-6)
  assert_true((y1 - 20.0).abs() < 1.0e-6)
  assert_true((z0 + 1.25).abs() < 1.0e-6)
  assert_true((z1 - 1.25).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  // Two faces plus 5 x 5 holes.
  assert_eq(part.connectors().length(), 2 + 25)
  let hole = match part.connector("hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
  assert_true((hole.diameter_mm.unwrap() - 4.0).abs() < 1.0e-6)
  assert_true((hole.placement.trans.0 + 16.0).abs() < 1.0e-6)
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = (40.0 * 40.0 - 25.0 * @math.PI * 2.0 * 2.0) * 2.5
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
}

///|
test "goBILDA 3x5 grid plate is 24 x 40 mm" {
  let part = gobilda_ok(@gobilda.gobilda_grid_plate(cols=3, rows=5))
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((x1 - x0 - 24.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 40.0).abs() < 1.0e-6)
  assert_eq(part.connectors().length(), 2 + 15)
}

///|
test "goBILDA grid plate family presets" {
  let family = gobilda_spec(@gobilda.gobilda_grid_plate_family())
  let names = family.variant_names()
  for
    variant in [
      "3x5", "5x5", "5x7", "5x9", "5x11", "5x17", "7x7", "7x11", "11x29",
    ] {
    assert_true(names.contains(variant))
  }
  let part = gobilda_ok(family.build_variant("11x29"))
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true((x1 - x0 - 88.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 232.0).abs() < 1.0e-6)
}

///|
test "goBILDA grid plate rejects invalid counts" {
  assert_true(@gobilda.gobilda_grid_plate(cols=0) is Err(_))
  assert_true(@gobilda.gobilda_grid_plate(rows=0) is Err(_))
  assert_true(@gobilda.gobilda_grid_plate(thickness_mm=0.0) is Err(_))
}
