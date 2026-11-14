///|
test "herringbone planetary gearbox exposes ring and gear connectors" {
  let params = match
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=1.0,
      gear_length_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let part = match @planetary.herringbone_planetary_gearbox(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = part.connectors().map(fn(c) { c.name })
  assert_true(names.contains("ring-outer-seat"))
  assert_true(names.contains("sun-pitch"))
  assert_true(names.contains("planet-1-pitch"))
}
