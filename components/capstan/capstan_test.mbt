///|
test "capstan layout computes pitch ratio, wraps, and signed direction" {
  assert_true(@capstan.CapstanParams::new(capstan_radius_mm=0.0) is Err(_))
  assert_true(@capstan.CapstanParams::new(travel_deg=400.0) is Err(_))
  let open_p = match
    @capstan.CapstanParams::new(
      capstan_radius_mm=8.0,
      driven_radius_mm=48.0,
      cable_diameter_mm=1.0,
      crossed=false,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let open_l = @capstan.capstan_layout(open_p)
  // (48 + 0.5) / (8 + 0.5) = 48.5 / 8.5.
  assert_true((open_l.signed_reduction - 48.5 / 8.5).abs() < 1.0e-9)
  assert_true(open_l.required_wraps >= 4)

  let cross_p = match @capstan.CapstanParams::new(crossed=true) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let cross_l = @capstan.capstan_layout(cross_p)
  assert_true(cross_l.signed_reduction < 0.0)
}

///|
test "capstan_drive compiles to valid STEP in both open and crossed modes" {
  for crossed in [false, true] {
    let params = match @capstan.CapstanParams::new(crossed~) {
      Ok(p) => p
      Err(e) => abort(e.message())
    }
    let comp = match @capstan.capstan_drive(params) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    let names = comp.connectors().map(fn(c) { c.name })
    assert_true(names.contains("input-bore"))
    assert_true(names.contains("output-bore"))
    let step_text = comp.to_design().to_step_file()
    assert_true(step_text.contains("ISO-10303-21;"))
    assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
  }
}
