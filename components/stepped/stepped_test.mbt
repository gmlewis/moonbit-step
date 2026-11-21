///|
test "stepped planetary params validation and exact reduction formula" {
  // Reject invalid tooth counts / colliding planets.
  assert_true(@stepped.SteppedPlanetaryParams::new(sun_teeth=4) is Err(_))
  assert_true(@stepped.SteppedPlanetaryParams::new(planet_count=1) is Err(_))
  // Default: Zs=12, Zp1=24, Zp2=10 => Zr=46, R = 1 + (46*24)/(12*10) = 10.2.
  let params = match @stepped.SteppedPlanetaryParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @stepped.stepped_planetary_layout(params)
  assert_eq(layout.ring_teeth, 46)
  assert_true((layout.signed_reduction - 10.2).abs() < 1.0e-9)
  // Coaxial center distance check: m*(Zs + Zp1)/2 == m*(Zr - Zp2)/2.
  let a1 = params.module_mm *
    (params.sun_teeth + params.planet_sun_teeth).to_double() /
    2.0
  let a2 = params.module_mm *
    (layout.ring_teeth - params.planet_ring_teeth).to_double() /
    2.0
  assert_true((a1 - a2).abs() < 1.0e-9)
}

///|
test "stepped_planetary_gearbox compiles to valid STEP with connectors" {
  let params = match @stepped.SteppedPlanetaryParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let comp = match @stepped.stepped_planetary_gearbox(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = comp.connectors().map(fn(c) { c.name })
  assert_true(names.contains("ring-outer-seat"))
  assert_true(names.contains("input-bore"))
  assert_true(names.contains("output-face"))
  let step_text = comp.to_design().to_step_file()
  assert_true(step_text.contains("ISO-10303-21;"))
  assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
}
