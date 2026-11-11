///|
/// Keyed shaft and keyway tests.

//|
fn keyed_section_radius(p : @cad.Vec2) -> Double {
  Double::sqrt(p.0 * p.0 + p.1 * p.1)
}

///|
test "keyed shaft cross-section is a simple notched disc" {
  let diameter = 20.0
  let width = 6.0
  let depth = 3.5
  let section = match
    @motion.keyed_shaft_cross_section(diameter, width, depth, segments=64) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(@cad.Profile2D::is_simple(section))
  // The disc area minus the rectangular notch; the notch removes material.
  let full_circle = @math.PI * (diameter / 2.0) * (diameter / 2.0)
  let area = @cad.polygon_area_2d(section).abs()
  assert_true(area < full_circle)
  // The notch floor is at radius - depth = 6.5 and the slot sides at +-3.
  let radius = diameter / 2.0
  let mut has_floor = false
  let mut has_left = false
  let mut has_right = false
  for (x, y) in section {
    if (y - (radius - depth)).abs() < 1.0e-9 &&
      (x.abs() - width / 2.0).abs() < 1.0e-9 {
      has_floor = true
    }
    if (x + width / 2.0).abs() < 1.0e-9 {
      has_left = true
    }
    if (x - width / 2.0).abs() < 1.0e-9 {
      has_right = true
    }
  }
  assert_true(has_floor && has_left && has_right)
  // Every vertex stays inside the nominal shaft cylinder.
  for p in section {
    assert_true(keyed_section_radius(p) <= radius + 1.0e-9)
  }
}

///|
test "keyed shaft keyway parameter validation" {
  assert_true(@motion.keyed_shaft_cross_section(20.0, 20.0, 3.0) is Err(_))
  assert_true(@motion.keyed_shaft_cross_section(20.0, 6.0, 11.0) is Err(_))
  // depth 0.1 leaves the flat bottom above the local shaft surface (9.9 > 9.54)
  assert_true(@motion.keyed_shaft_cross_section(20.0, 6.0, 0.1) is Err(_))
  assert_true(@motion.keyed_shaft(20.0, 40.0, 6.0, 3.5) is Ok(_))
  assert_true(@motion.keyed_shaft(20.0, 0.0, 6.0, 3.5) is Err(_))
}

///|
test "keyed shaft builds one watertight body with the keyway feature" {
  let shaft = match @motion.keyed_shaft(20.0, 40.0, 6.0, 3.5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(shaft.layers().length(), 1)
  assert_true(shaft.features().has_modeled("keyway"))
  assert_true(shaft.features().has_omitted("keyway-end-radius"))
  let (x0, x1, y0, y1, z0, z1) = shaft.bounding_box()
  // The section is a polygonal approximation, so the sampled extremes sit just
  // inside the nominal circle, but never outside it.
  assert_true(x1 <= 10.0 + 1.0e-9 && x0 >= -10.0 - 1.0e-9)
  assert_true(x1 > 9.9 && x0 < -9.9)
  // The keyway removes the +Y crown, so the top of the bbox is the slot
  // shoulder at sqrt(10^2 - 3^2) = 9.539, not the nominal radius. The shoulder
  // is an exact section vertex.
  let shoulder = Double::sqrt(10.0 * 10.0 - 3.0 * 3.0)
  assert_true((y1 - shoulder).abs() < 1.0e-6)
  assert_true(y0 >= -10.0 - 1.0e-9 && y0 < -9.9)
  assert_true(z0.abs() < 1.0e-9 && (z1 - 40.0).abs() < 1.0e-9)
  let step = shaft.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}

///|
test "keyed shaft parameter sweep stays simple and inside the shaft" {
  for diameter in [12.0, 20.0, 30.0] {
    let width = diameter * 0.3
    let depth = diameter * 0.15
    let section = match
      @motion.keyed_shaft_cross_section(diameter, width, depth, segments=48) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    assert_true(@cad.Profile2D::is_simple(section))
    let radius = diameter / 2.0
    let area = @cad.polygon_area_2d(section).abs()
    assert_true(area > 0.0 && area < @math.PI * radius * radius)
    for p in section {
      assert_true(keyed_section_radius(p) <= radius + 1.0e-9)
    }
    let shaft = match
      @motion.keyed_shaft(diameter, 2.0 * diameter, width, depth) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    let (x0, x1, y0, y1, z0, z1) = shaft.bounding_box()
    assert_true(x1 > x0 && y1 > y0 && z1 > z0)
    assert_true((z1 - 2.0 * diameter).abs() < 1.0e-9)
  }
}

///|
test "a key sized from the keyway fits inside the keyway envelope" {
  let diameter = 20.0
  let width = 6.0
  let depth = 3.5
  let clearance = 0.1
  let key = match
    @motion.key_for_keyway(width, depth, 25.0, width_clearance_mm=clearance) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (kx0, kx1, ky0, ky1, kz0, kz1) = key.bounding_box()
  let key_half_width = (kx1 - kx0) / 2.0
  let key_height = ky1 - ky0
  let key_length = kz1 - kz0
  assert_true((key_half_width - (width - clearance) / 2.0).abs() < 1.0e-9)
  assert_true((key_height - depth).abs() < 1.0e-9)
  assert_true((key_length - 25.0).abs() < 1.0e-9)
  // The key's X range is strictly inside the keyway slot, its bottom sits on
  // the keyway floor, and its top does not exceed the shaft outside diameter.
  let radius = diameter / 2.0
  let floor = radius - depth
  assert_true(key_half_width < width / 2.0)
  // The shaft surface above the key's side is still above the keyway floor, so
  // the key never pokes through the shaft wall.
  let surface_at_key_side = Double::sqrt(
    radius * radius - key_half_width * key_half_width,
  )
  assert_true(surface_at_key_side > floor)
  assert_true(floor + key_height <= radius + 1.0e-9)
  // A keyway with no clearance room is rejected.
  assert_true(@motion.key_for_keyway(0.05, 3.5, 25.0) is Err(_))
}

///|
test "key height is independent of the keyway depth" {
  let key = match @motion.key_for_keyway(6.0, 3.5, 25.0, key_height_mm=6.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (_x0, _x1, y0, y1, _z0, _z1) = key.bounding_box()
  assert_true((y0 - 0.0).abs() < 1.0e-9)
  assert_true((y1 - 6.0).abs() < 1.0e-9)
  // A local origin at the bottom-left-near corner is documented; the key is
  // not silently translated to the shaft frame.
  assert_true(key.description().contains("protrudes into the hub"))
  assert_true(
    @motion.key_for_keyway(6.0, 3.5, 25.0, key_height_mm=-1.0) is Err(_),
  )
}
