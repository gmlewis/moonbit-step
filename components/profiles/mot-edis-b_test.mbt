///|
test "MotEDis B-type 20 profile reproduces the measured section area" {
  let part = mbracket_ok(@profiles.mot_edis_b_profile_of("20", length_mm=100.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 10.0).abs() < 1.0e-6)
  assert_true((x1 - 10.0).abs() < 1.0e-6)
  assert_true((y0 + 10.0).abs() < 1.0e-6)
  assert_true((y1 - 10.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 100.0).abs() < 1.0e-6)
  assert_eq(part.layers().length(), 1)
  let mut volume = 0.0
  for layer in part.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => volume += v
      Err(e) => abort(e.message())
    }
  }
  // Measured outer 190.981 mm2 minus the 28.942 mm2 core bore, times 100 mm.
  assert_true((volume - 16203.93).abs() < 1.0)
}

///|
test "MotEDis B-type 30 and 40 profiles include their corner cavities" {
  let p30 = mbracket_ok(@profiles.mot_edis_b_profile_of("30", length_mm=50.0))
  let (_x0, x1, _y0, _y1, _z0, _z1) = p30.bounding_box()
  assert_true((x1 - 15.0).abs() < 1.0e-6)
  let p40 = mbracket_ok(@profiles.mot_edis_b_profile_of("40", length_mm=50.0))
  let (_x0, x1, _y0, _y1, _z0, _z1) = p40.bounding_box()
  assert_true((x1 - 20.0).abs() < 1.0e-6)
  let mut v30 = 0.0
  for layer in p30.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => v30 += v
      Err(e) => abort(e.message())
    }
  }
  // 439.005 - 57.948 - 4 x 16.782 = 313.931 mm2, times 50 mm.
  assert_true((v30 - 15696.55).abs() < 1.0)
  let mut v40 = 0.0
  for layer in p40.layers() {
    match layer.shape.analysis_volume() {
      Ok(v) => v40 += v
      Err(e) => abort(e.message())
    }
  }
  // 880.456 - 101.697 - 4 x 54.448 = 560.968 mm2, times 50 mm.
  assert_true((v40 - 28048.4).abs() < 1.0)
}

///|
test "MotEDis B-type profile family and errors" {
  let family = mbracket_spec(@profiles.mot_edis_b_family())
  assert_true(family.variant_names().contains("1000mm"))
  let part = mbracket_ok(family.build_variant("250mm"))
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 250.0).abs() < 1.0e-6)
  assert_true(@profiles.mot_edis_b_profile_of("25") is Err(_))
}
