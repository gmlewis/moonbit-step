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
test "spur gear blank envelope matches the tip cylinder" {
  let params = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      face_width_mm=16.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let part = match @gears.spur_gear_envelope(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -22.0))
  assert_true(close(x1, 22.0))
  assert_true(close(z0, -8.0))
  assert_true(close(z1, 8.0))
  let layers = part.layers()
  let inventory = layers[0].shape.surface_inventory()
  assert_true(inventory.plane == 2)
  assert_true(inventory.cylinder == 2)
  let volume = match layers[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(
    (volume - @math.PI * (22.0 * 22.0 - 4.0 * 4.0) * 16.0).abs() < 0.01,
  )
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

///|
test "gear root fillet rounds the root and stays a simple polygon" {
  let base = @gears.external_involute_outline(2.0, 20, 20.0)
  let filleted = match
    @gears.external_involute_outline_ex(
      2.0,
      20,
      20.0,
      root_fillet_radius_mm=0.4,
      fillet_segments=6,
    ) {
    Ok(o) => o
    Err(e) => abort(e.message())
  }
  assert_true(@cad.Profile2D::is_simple(filleted))
  assert_true(filleted.length() > base.length())
  let geom = @gears.involute_gear_geometry(2.0, 20, 20.0)
  // A root fillet adds material at the re-entrant root. Collapsing the fine
  // root arc to a chord introduces at most a small sagitta, so the measured
  // root radius stays within 0.1 mm of the nominal root circle.
  assert_true(
    @gears.gear_outline_min_radius(filleted) >= geom.root_radius_mm - 0.1,
  )
  assert_true(
    @gears.gear_outline_max_radius(filleted) <= geom.outer_radius_mm + 1.0e-6,
  )
  let area0 = @gears.involute_outline_area(base)
  let area1 = @gears.involute_outline_area(filleted)
  // The outline is wound clockwise (negative signed area); a root fillet adds
  // material, so its absolute area grows.
  assert_true(area1.abs() > area0.abs())
  // The polyline arc deviation is the chord error: 0.054 mm at 6 segments and
  // below 0.01 mm at 24 segments.
  assert_true(@gears.gear_outline_deviation_mm(0.4, 6) < 0.06)
  assert_true(@gears.gear_outline_deviation_mm(0.4, 24) < 0.01)
}

///|
test "gear tip chamfer bevels the tip and stays a simple polygon" {
  let base = @gears.external_involute_outline(2.0, 20, 20.0)
  let chamfered = match
    @gears.external_involute_outline_ex(2.0, 20, 20.0, tip_chamfer_mm=0.1) {
    Ok(o) => o
    Err(e) => abort(e.message())
  }
  assert_true(@cad.Profile2D::is_simple(chamfered))
  assert_true(chamfered.length() >= 2 * 20)
  let geom = @gears.involute_gear_geometry(2.0, 20, 20.0)
  assert_true(
    @gears.gear_outline_max_radius(chamfered) <= geom.outer_radius_mm + 1.0e-6,
  )
  // A tip chamfer removes material from the tip, so the absolute area shrinks.
  assert_true(
    @gears.involute_outline_area(chamfered).abs() <
    @gears.involute_outline_area(base).abs(),
  )
}

///|
test "gear feature parameters reject oversized values" {
  assert_true(
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      root_fillet_radius_mm=1.0,
    )
    is Err(_),
  )
  assert_true(
    @gears.SpurGearParams::new(module_mm=2.0, teeth=20, tip_chamfer_mm=1.0)
    is Err(_),
  )
  assert_true(
    @gears.external_involute_outline_ex(
      2.0,
      20,
      20.0,
      root_fillet_radius_mm=-1.0,
    )
    is Err(_),
  )
  assert_true(
    @gears.external_involute_outline_ex(
      2.0,
      20,
      20.0,
      root_fillet_radius_mm=5.0,
    )
    is Err(_),
  )
}

///|
test "spur gear with root fillet and tip chamfer builds and records them" {
  let params = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
      root_fillet_radius_mm=0.4,
      tip_chamfer_mm=0.1,
      fillet_segments=6,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let gear = match @gears.spur_gear(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = gear.features()
  assert_true(features.has_modeled("root-fillet"))
  assert_true(features.has_modeled("tip-chamfer"))
  assert_true(features.has_approximated("root-fillet-arc"))
  let step = gear.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}
