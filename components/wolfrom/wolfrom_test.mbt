///|
test "wolfrom 3K params validation and exact Willis reduction ratio" {
  // Reject ring_tooth_diff == 0 or not divisible by planet_count.
  assert_true(@wolfrom.WolfromParams::new(ring_tooth_diff=0) is Err(_))
  assert_true(
    @wolfrom.WolfromParams::new(ring_tooth_diff=2, planet_count=3) is Err(_),
  )
  // Default: Zs=12, Zp=18, Zr1=48, Zr2=51 => R = (60*51)/(12*3) = +85.0.
  let params = match @wolfrom.WolfromParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @wolfrom.wolfrom_layout(params)
  assert_eq(layout.fixed_ring_teeth, 48)
  assert_eq(layout.output_ring_teeth, 51)
  assert_true((layout.signed_reduction - 85.0).abs() < 1.0e-9)
  // Reversed tooth diff: Zr2=45 => R = (60*45)/(12*(-3)) = -75.0.
  let rev_params = match @wolfrom.WolfromParams::new(ring_tooth_diff=-3) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let rev_layout = @wolfrom.wolfrom_layout(rev_params)
  assert_true((rev_layout.signed_reduction + 75.0).abs() < 1.0e-9)
}

///|
test "wolfrom_gearbox compiles to valid STEP with expected connectors" {
  let params = match @wolfrom.WolfromParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let comp = match @wolfrom.wolfrom_gearbox(params) {
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
