///|
/// Black-box tests for the herringbone planetary gearbox component.

///|
fn hb_params(
  num_elbows~ : Int32 = 4,
  hole_type~ : String = "None",
) -> @planetary.HerringbonePlanetaryParams {
  match
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=1.0,
      gear_length_mm=10.0,
      helix_angle_deg=30.0,
      pressure_angle_deg=20.0,
      num_elbows~,
      resolution=9,
      hole_type~,
      hole_radius_mm=3.0,
      tolerance_mm=0.0833333,
      outer_thickness_mm=3.33333,
      sun_teeth=12,
      planet_count=3,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
}

///|
fn hb_layer(component : @common.Component, suffix : String) -> Bool {
  for layer in component.layers() {
    if layer.name.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn hb_connector(component : @common.Component, name : String) -> Bool {
  for connector in component.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "planetary params validate and resolve tooth counts" {
  let p = hb_params()
  assert_eq(p.planet_teeth, 12)
  assert_eq(p.ring_teeth, 36)
  assert_true(
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=0.0,
      gear_length_mm=10.0,
    )
    is Err(_),
  )
  // (sun + ring) must be divisible by the planet count.
  assert_true(
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=1.0,
      gear_length_mm=10.0,
      sun_teeth=13,
      planet_count=3,
    )
    is Err(_),
  )
  assert_true(
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=1.0,
      gear_length_mm=10.0,
      num_elbows=-1,
    )
    is Err(_),
  )
}

///|
test "straight planetary is an exact arc extrusion with connectors" {
  let component = match
    @planetary.herringbone_planetary_gearbox(hb_params(num_elbows=0)) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.layers().length(), 5)
  for suffix in ["sun", "planet-1", "planet-2", "planet-3", "ring"] {
    if !hb_layer(component, suffix) {
      abort("missing layer " + suffix)
    }
  }
  for
    name in [
      "sun-pitch", "sun-face-a", "sun-face-b", "planet-1-pitch", "planet-2-pitch",
      "planet-3-pitch", "ring-outer-seat", "ring-pitch", "ring-face-a", "ring-face-b",
    ] {
    if !hb_connector(component, name) {
      abort("missing connector " + name)
    }
  }
  let step = component.to_step()
  assert_true(step.contains("CYLINDRICAL_SURFACE("))
  assert_false(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  // No planar tooth facets: only the two caps per gear plus the ring faces.
  let layout = @planetary.herringbone_planetary_layout(hb_params(num_elbows=0))
  let (x0, x1, _y0, _y1, z0, z1) = component.bounding_box()
  let outer = layout.ring_outer_radius_mm
  assert_true((x1 - outer).abs() < 1.0e-6)
  assert_true((x0 + outer).abs() < 1.0e-6)
  assert_true((z1 - z0 - 10.0).abs() < 1.0e-6)
}

///|
test "herringbone planetary keeps the swept geometry and connectors" {
  let component = match
    @planetary.herringbone_planetary_gearbox(hb_params(num_elbows=4)) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(component.layers().length(), 5)
  for suffix in ["sun", "planet-1", "planet-2", "planet-3", "ring"] {
    if !hb_layer(component, suffix) {
      abort("missing layer " + suffix)
    }
  }
  for
    name in [
      "sun-pitch", "planet-1-pitch", "planet-2-pitch", "planet-3-pitch", "ring-outer-seat",
      "ring-pitch",
    ] {
    if !hb_connector(component, name) {
      abort("missing connector " + name)
    }
  }
  let layout = @planetary.herringbone_planetary_layout(hb_params(num_elbows=4))
  let (x0, x1, _y0, _y1, z0, z1) = component.bounding_box()
  let outer = layout.ring_outer_radius_mm
  assert_true((x1 - outer).abs() < 1.0e-6)
  assert_true((x0 + outer).abs() < 1.0e-6)
  assert_true((z1 - z0 - 10.0).abs() < 1.0e-6)
  // The flanks are ruled B-spline surfaces (one per profile edge), not
  // triangulated planar facets.
  let step = component.to_step()
  assert_true(step.contains("B_SPLINE_SURFACE_WITH_KNOTS("))
}

///|
test "planetary hole type adds a bore connector" {
  let component = match
    @planetary.herringbone_planetary_gearbox(
      hb_params(num_elbows=0, hole_type="Circular"),
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(hb_connector(component, "sun-bore"))
  assert_true(hb_connector(component, "planet-1-bore"))
  let step = component.to_step()
  assert_true(step.contains("CYLINDRICAL_SURFACE("))
}
