///|
test "Maker Store 40x40 L plate matches the PLATE-40X40L drawing" {
  let part = mech_ok(@mechanisms.makerstore_l_plate())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, 40.0))
  assert_true(mech_close(y0, -20.0))
  assert_true(mech_close(y1, 20.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 40.0))
  // Two legs, three through holes each in a 3x3 grid.
  assert_eq(part.layers().length(), 2)
  assert_eq(part.connectors().length(), 20)
  assert_true(mech_has_connector(part, "base-hole-1"))
  assert_true(mech_has_connector(part, "base-hole-9"))
  assert_true(mech_has_connector(part, "upright-hole-9"))
  assert_true(mech_has_connector(part, "base-face"))
  assert_true(mech_has_connector(part, "upright-face"))
  let hole = mech_connector(part, "base-hole-1")
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
  assert_true(hole.gender is @common.MateGender::Female)
  assert_true(mech_close(hole.diameter_mm.unwrap(), 5.0))
  // Centred 3x3 grid: first hole at 10 mm from the corner, 10 mm each side.
  assert_true(mech_close(hole.placement.trans.0, 10.0))
  assert_true(mech_close(hole.placement.trans.1, -10.0))
  let centre = mech_connector(part, "base-hole-5")
  assert_true(mech_close(centre.placement.trans.0, 20.0))
  assert_true(mech_close(centre.placement.trans.1, 0.0))
  // Each leg is a 40x40 plate with nine 5 mm holes through 3 mm.
  let plate_area = 40.0 * 40.0 - 9.0 * @math.PI * 2.5 * 2.5
  let expected_layer = plate_area * 3.0
  for layer in part.layers() {
    let volume = match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
    assert_true((volume - expected_layer).abs() < 1.0e-6 * expected_layer)
  }
}

///|
test "Maker Store L plate family presets and 40x80 grid" {
  let family = match @mechanisms.l_plate_family() {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let names = family.variant_names()
  assert_true(names.contains("plate-40x40l"))
  assert_true(names.contains("plate-40x80l"))
  let part = mech_ok(family.build_variant("plate-40x80l"))
  let (x0, x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, 80.0))
  assert_true(mech_close(z1, 40.0))
  // 80 mm base leg at 10 mm pitch holds 7 rows of 3; the 40 mm upright holds 3x3.
  assert_eq(part.connectors().length(), 2 + 7 * 3 + 3 * 3)
  assert_true(
    mech_close(mech_connector(part, "base-hole-1").placement.trans.0, 10.0),
  )
}

///|
test "Maker Store L plate rejects bad pitch and oversized holes" {
  assert_true(@mechanisms.makerstore_l_plate(pitch_mm=0.0) is Err(_))
  assert_true(@mechanisms.makerstore_l_plate(hole_diameter_mm=50.0) is Err(_))
}
