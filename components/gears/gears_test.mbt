///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn gear20() -> @gears.SpurGearParams {
  match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
}

///|
test "involute gear radii" {
  let g = @gears.involute_gear_geometry(2.0, 20, 20.0)
  assert_true(close(g.pitch_radius_mm, 20.0))
  assert_true(close(g.base_radius_mm, 20.0 * 0.9396926207859084))
  assert_true(close(g.root_radius_mm, 17.5))
  assert_true(close(g.outer_radius_mm, 22.0))
}

///|
test "involute outline is a closed positive-area polygon" {
  let outline = @gears.external_involute_outline(2.0, 20, 20.0)
  assert_true(outline.length() > 100)
  let area = @gears.involute_outline_area(outline)
  assert_true(area.abs() > 100.0)
  let mut max_r = 0.0
  for (x, y) in outline {
    let r = Double::sqrt(x * x + y * y)
    if r > max_r {
      max_r = r
    }
  }
  assert_true(max_r <= 22.0 + 1.0e-6)
  assert_true(max_r > 21.0)
}

///|
test "spur gear component dimensions" {
  let params = gear20()
  let gear = match @gears.spur_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = gear.bounding_box()
  assert_true(x1 <= 22.0 + 1.0e-6)
  assert_true(x0 >= -22.0 - 1.0e-6)
  assert_true(y1 <= 22.0 + 1.0e-6)
  assert_true(y0 >= -22.0 - 1.0e-6)
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 10.0))
  assert_eq(gear.layers().length(), 1)
  assert_true(gear.name().contains("m2-z20"))
}

///|
test "spur gear parameter validation" {
  assert_true(@gears.SpurGearParams::new(module_mm=0.0, teeth=20) is Err(_))
  assert_true(@gears.SpurGearParams::new(module_mm=2.0, teeth=4) is Err(_))
  assert_true(
    @gears.SpurGearParams::new(module_mm=2.0, teeth=20, pressure_angle_deg=50.0)
    is Err(_),
  )
  assert_true(
    @gears.SpurGearParams::new(module_mm=2.0, teeth=20, bore_diameter_mm=40.0)
    is Err(_),
  )
}

///|
test "gear pair centre distance and layout" {
  let driver = gear20()
  let driven = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=40,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let center = @gears.gear_pair_center_distance(driver, driven, offset_mm=0.05)
  assert_true(close(center, 60.05))
  let pair = match @gears.gear_pair(driver, driven, offset_mm=0.05) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_eq(pair.count(), 2)
  let (x0, x1, _y0, _y1, z0, z1) = pair.bounding_box()
  assert_true(x0 <= -21.0)
  assert_true(x1 >= 60.0 + 41.0)
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 10.0))
}

///|
test "gear pair rejects mismatched module" {
  let driver = gear20()
  let driven = match @gears.SpurGearParams::new(module_mm=2.5, teeth=40) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(@gears.gear_pair(driver, driven) is Err(_))
}

///|
test "planetary parameter validation" {
  let good = @gears.PlanetaryParams::new(
    module_mm=2.0,
    sun_teeth=12,
    planet_teeth=12,
    planet_count=3,
    face_width_mm=10.0,
    sun_bore_mm=6.0,
    planet_bore_mm=4.0,
  )
  assert_true(good is Ok(_))
  assert_true(
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=10,
      planet_teeth=6,
      planet_count=3,
    )
    is Err(_),
  )
  assert_true(
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=12,
      planet_teeth=12,
      planet_count=5,
    )
    is Err(_),
  )
}

///|
test "planetary set layout and ring envelope" {
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=12,
      planet_teeth=12,
      planet_count=3,
      face_width_mm=10.0,
      sun_bore_mm=6.0,
      planet_bore_mm=4.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(close(params.center_distance(), 24.0))
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_eq(set.count(), 5)
  let (x0, x1, y0, y1, z0, z1) = set.bounding_box()
  // Ring pitch = 36, root = 38.5, default outer wall 5 -> radius 43.5.
  assert_true(x1 <= 43.5 + 1.0e-6)
  assert_true(x0 >= -43.5 - 1.0e-6)
  assert_true(y1 <= 43.5 + 1.0e-6)
  assert_true(y0 >= -43.5 - 1.0e-6)
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 10.0))
}
