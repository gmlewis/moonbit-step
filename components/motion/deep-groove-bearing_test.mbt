///|
/// Black-box tests for the full-complement deep-groove bearing.

///|
fn dgb_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn dgb_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "deep groove bearing derives a full complement with retaining shoulders" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let spec = match @motion.deep_groove_bearing_spec(size) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  // 608: ball diameter 0.285 x 14 = 3.99 mm; the largest full complement at the
  // 7.5 mm pitch circle with a 0.15 x ball-radius web is ten balls.
  assert_true(dgb_close(spec.ball_diameter_mm, 3.99, 1.0e-9))
  assert_eq(spec.ball_count, 10)
  assert_true(dgb_close(spec.pitch_radius_mm, 7.5, 1.0e-9))
  // The shoulders overlap the ball envelope, so the balls are trapped axially.
  let ball_radius = spec.ball_diameter_mm / 2.0
  assert_true(
    spec.outer_shoulder_radius_mm < spec.pitch_radius_mm + ball_radius,
  )
  assert_true(
    spec.inner_shoulder_radius_mm > spec.pitch_radius_mm - ball_radius,
  )
  assert_true(spec.min_ring_wall_mm > 0.0)
  assert_true(
    dgb_close(
      spec.min_ring_wall_mm,
      spec.inner_groove_bottom_mm - size.bore_mm / 2.0,
      1.0e-9,
    ),
  )
}

///|
test "deep groove bearing has grooved rings and a full ring of balls" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.deep_groove_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let spec = match @motion.deep_groove_bearing_spec(size) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let layers = part.layers()
  assert_eq(layers.length(), spec.ball_count + 2)
  assert_true(layers[0].name.has_suffix("outer-ring"))
  assert_true(layers[1].name.has_suffix("inner-ring"))
  // Each ring carries a toroidal raceway groove.
  assert_true(layers[0].shape.surface_inventory().torus >= 1)
  assert_true(layers[1].shape.surface_inventory().torus >= 1)
  // Eight balls would be a thin complement; the default is a full complement.
  assert_true(spec.ball_count >= 9)
  let ball_layers = layers.filter(fn(layer) { layer.name.contains("ball-") })
  assert_eq(ball_layers.length(), spec.ball_count)
  // The watertight ball is one spherical band plus two tiny polar caps.
  let ball_inventory = ball_layers[0].shape.surface_inventory()
  assert_eq(ball_inventory.sphere, 1)
  assert_eq(ball_inventory.plane, 2)
  for name in ["bore", "outer-seat", "face-negative", "face-positive"] {
    if !dgb_has_connector(part, name) {
      abort("deep groove bearing is missing connector " + name)
    }
  }
}

///|
test "deep groove bearing detailed rings carry chamfers" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let simplified = match
    @motion.deep_groove_bearing(size, detail=@common.DetailLevel::Simplified) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let detailed = match
    @motion.deep_groove_bearing(size, detail=@common.DetailLevel::Detailed) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(simplified.layers()[0].shape.surface_inventory().cone, 0)
  // Each ring carries two rim chamfers and two shoulder chamfers.
  assert_eq(detailed.layers()[0].shape.surface_inventory().cone, 4)
  assert_eq(detailed.layers()[1].shape.surface_inventory().cone, 4)
}

///|
test "deep groove bearing rejects an overlapping ball count" {
  let size = match @motion.bearing_size("608") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(@motion.deep_groove_bearing(size, ball_count=40) is Err(_))
  assert_true(@motion.deep_groove_bearing(size, ball_count=2) is Err(_))
  assert_true(@motion.deep_groove_bearing(size, ball_count=6) is Ok(_))
}
