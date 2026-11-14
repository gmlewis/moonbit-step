///|
fn tire_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn tire_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "measured tire envelope matches the owner-authored model" {
  let spec = @motion.tire_spec()
  assert_true(@motion.tire_spec_valid(spec) is Ok(_))
  let wheel = tire_ok(@motion.measured_tire())
  let (x0, x1, y0, y1, z0, z1) = wheel.bounding_box()
  assert_true(tire_close(x0, -38.1))
  assert_true(tire_close(x1, 0.0))
  assert_true(tire_close(y0, -88.9))
  assert_true(tire_close(y1, 88.9))
  assert_true(tire_close(z0, -88.9))
  assert_true(tire_close(z1, 88.9))
  assert_eq(wheel.layers().length(), 9)
  assert_true(wheel.features().modeled.contains("inset-plate"))
  assert_true(wheel.features().omission_reason("tread-pattern") is Some(_))
}

///|
test "measured tire layer volumes sum to the reference volume" {
  let wheel = tire_ok(@motion.measured_tire())
  let mut total = 0.0
  for layer in wheel.layers() {
    let volume = match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort("tire layer \{layer.name} volume: \{e.message()}")
    }
    total = total + volume
  }
  // The reference measures 512793 mm3; the analytic sum is 512540.7 mm3.
  assert_true((total - 512793.0).abs() / 512793.0 < 0.001)
}

///|
test "tire exposes hub, bore, and tread connectors" {
  let wheel = tire_ok(@motion.measured_tire())
  for name in ["hub-bore", "hub-face", "hub-rear", "tread"] {
    assert_true(wheel.connector(name) is Ok(_))
  }
  let bore = match wheel.connector("hub-bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(tire_close(bore.diameter_mm.unwrap(), 12.7))
  assert_true(tire_close(bore.depth_mm.unwrap(), 34.925))
}

///|
test "tire parameters can be overridden for a measured wheel" {
  let spec : @motion.TireSpec = {
    ..@motion.tire_spec(),
    tire_outer_diameter_mm: 152.4,
    tire_inner_diameter_mm: 101.6,
    tire_width_mm: 25.4,
    hub_outer_diameter_mm: 19.05,
    hub_bore_diameter_mm: 9.525,
    hub_length_mm: 25.4,
    hub_inset_mm: 12.7,
    inset_thickness_mm: 1.5,
    rib_thickness_mm: 1.5,
    rib_count: 5,
  }
  assert_true(@motion.tire_spec_valid(spec) is Ok(_))
  let wheel = tire_ok(@motion.tire(spec))
  let (x0, x1, _y0, _y1, _z0, _z1) = wheel.bounding_box()
  assert_true(tire_close(x0, -25.4))
  assert_true(tire_close(x1, 0.0))
  assert_eq(wheel.layers().length(), 8)
}

///|
test "tire validation rejects inconsistent envelopes" {
  let bad_inner : @motion.TireSpec = {
    ..@motion.tire_spec(),
    tire_inner_diameter_mm: 177.8,
  }
  assert_true(@motion.tire_spec_valid(bad_inner) is Err(_))
  let bad_bore : @motion.TireSpec = {
    ..@motion.tire_spec(),
    hub_bore_diameter_mm: 30.0,
  }
  assert_true(@motion.tire_spec_valid(bad_bore) is Err(_))
  let bad_inset : @motion.TireSpec = {
    ..@motion.tire_spec(),
    hub_inset_mm: 38.1,
  }
  assert_true(@motion.tire_spec_valid(bad_inset) is Err(_))
  let bad_ribs : @motion.TireSpec = { ..@motion.tire_spec(), rib_count: 2, }
  assert_true(@motion.tire_spec_valid(bad_ribs) is Err(_))
}
