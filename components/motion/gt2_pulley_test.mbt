///|
fn gt2_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn gt2_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "GT2 diameters follow pitch offset and tooth depth" {
  let geom = match @motion.gt2_geometry(20) {
    Ok(g) => g
    Err(e) => abort(e.message())
  }
  let pitch = 20.0 * 2.0 / @math.PI
  assert_true(gt2_near(geom.pitch_diameter_mm, pitch))
  assert_true(gt2_near(geom.outside_diameter_mm, pitch - 2.0 * 0.254))
  assert_true(gt2_near(geom.root_diameter_mm, pitch - 2.0 * 0.254 - 2.0 * 0.76))
  assert_true(@motion.gt2_geometry(8) is Err(_))
  assert_true(@motion.gt2_geometry(10) is Ok(_))
}

///|
test "GT2 pulley has a flange envelope, bore, and pitch datum" {
  let part = match @motion.gt2_pulley(20, 6.0, 5.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let geom = match @motion.gt2_geometry(20) {
    Ok(g) => g
    Err(e) => abort(e.message())
  }
  let flange_radius = (geom.outside_diameter_mm + 2.0) / 2.0
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(gt2_near(x0, -flange_radius))
  assert_true(gt2_near(x1, flange_radius))
  assert_true(gt2_near(z0, 0.0))
  assert_true(gt2_near(z1, 6.0))
  assert_true(gt2_has_connector(part, "bore"))
  assert_true(gt2_has_connector(part, "pitch-datum"))
  assert_true(gt2_has_connector(part, "face-negative"))
  assert_true(gt2_has_connector(part, "face-positive"))
  let pitch = match part.connector("pitch-datum") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  match pitch.diameter_mm {
    Some(d) => assert_true(gt2_near(d, geom.pitch_diameter_mm))
    None => fail("expected pitch diameter")
  }
}

///|
test "GT2 pulley without flanges uses the outside diameter" {
  let part = match @motion.gt2_pulley(20, 6.0, 5.0, flanges=false) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let geom = match @motion.gt2_geometry(20) {
    Ok(g) => g
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, _z1) = part.bounding_box()
  assert_true(gt2_near(x0, -geom.outside_diameter_mm / 2.0))
  assert_true(gt2_near(x1, geom.outside_diameter_mm / 2.0))
}

///|
test "GT2 pulley rejects invalid parameters" {
  assert_true(@motion.gt2_pulley(20, 0.0, 5.0) is Err(_))
  assert_true(@motion.gt2_pulley(20, 6.0, 0.0) is Err(_))
  assert_true(@motion.gt2_pulley(20, 6.0, 12.0) is Err(_))
  assert_true(
    @motion.gt2_pulley(20, 6.0, 5.0, flange_diameter_mm=5.0) is Err(_),
  )
}
