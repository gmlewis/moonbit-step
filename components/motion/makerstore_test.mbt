///|
test "Maker Store aluminum spacer matches SHIM-SPAC OD 10 / ID 5" {
  let part = ok_motion(@motion.makerstore_aluminum_spacer())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 5.0).abs() < 1.0e-6)
  assert_true((x1 - 5.0).abs() < 1.0e-6)
  assert_true((y0 + 5.0).abs() < 1.0e-6)
  assert_true((y1 - 5.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 10.0).abs() < 1.0e-6)
  assert_true(motion_has_connector(part, "bore"))
  assert_true(motion_has_connector(part, "outer-seat"))
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = @math.PI / 4.0 * (10.0 * 10.0 - 5.0 * 5.0) * 10.0
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
}

///|
test "Maker Store spacer family exposes every published length" {
  let family = ok_motion_spec(@motion.makerstore_spacer_family())
  let names = family.variant_names()
  for
    length in [
      "len-3", "len-6", "len-6.5", "len-9", "len-10", "len-20", "len-30", "len-35",
      "len-40",
    ] {
    assert_true(names.contains(length))
  }
  let part = ok_motion(family.build_variant("len-3"))
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 3.0).abs() < 1.0e-6)
}

///|
test "Maker Store thrust bearing envelopes and connector seats" {
  let size = ok_motion_spec(@motion.thrust_bearing_size("F5-10M"))
  assert_true((size.bore_mm - 5.0).abs() < 1.0e-6)
  assert_true((size.outer_diameter_mm - 10.0).abs() < 1.0e-6)
  assert_true((size.height_mm - 4.0).abs() < 1.0e-6)
  let part = ok_motion(@motion.thrust_bearing(size))
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 5.0).abs() < 1.0e-6)
  assert_true((x1 - 5.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 4.0).abs() < 1.0e-6)
  let bore = match part.connector("bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((bore.diameter_mm.unwrap() - 5.0).abs() < 1.0e-6)
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = @math.PI / 4.0 * (10.0 * 10.0 - 5.0 * 5.0) * 4.0
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
  assert_true(@motion.thrust_bearing_size("F9-99M") is Err(_))
}

///|
test "Maker Store thrust bearing family presets" {
  let family = ok_motion_spec(@motion.thrust_bearing_family())
  for designation in ["f5-10m", "f5-12m", "f6-12m", "f8-16m"] {
    assert_true(family.variant_names().contains(designation))
  }
  let part = ok_motion(family.build_variant("f8-16m"))
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((z1 - 5.0).abs() < 1.0e-6)
  assert_true(family.build_values([("bore", 7.0), ("outer", 11.0)]) is Err(_))
}
