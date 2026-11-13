///|
test "smooth spur gear is one arc extrusion" {
  let params = match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let part = match @gears.spur_gear(params, smooth=true) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let step = part.to_step()
  assert_true(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  assert_true(step.contains("SURFACE_OF_LINEAR_EXTRUSION("))
  let inventory = part.layers()[0].shape.surface_inventory()
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.swept, 2)
}

///|
test "smooth internal ring gear is one arc extrusion" {
  let part = match @gears.internal_ring_gear_exact(2.0, 36, 10.0, smooth=true) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let step = part.to_step()
  assert_true(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  assert_true(step.contains("SURFACE_OF_LINEAR_EXTRUSION("))
  let inventory = part.layers()[0].shape.surface_inventory()
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.swept, 2)
}

///|
test "smooth planetary set uses smooth extrusions for every gear" {
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=12,
      planet_teeth=12,
      planet_count=3,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let set = match @gears.planetary_gear_set(params, smooth=true) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  for item in set.items() {
    let inventory = item.component.layers()[0].shape.surface_inventory()
    assert_eq(inventory.plane, 2)
    assert_true(inventory.swept >= 1)
  }
}
