///|
test "worm gear layout computes ratio, lead angle, and self-locking threshold" {
  assert_true(@worm.WormGearParams::new(worm_starts=0) is Err(_))
  assert_true(@worm.WormGearParams::new(wheel_teeth=6) is Err(_))
  // Single-start m=2, r1=10 => tan(gamma) = 2/(20) = 0.10 < mu=0.15 => self-locking!
  let lock_p = match
    @worm.WormGearParams::new(
      module_mm=2.0,
      worm_starts=1,
      wheel_teeth=30,
      worm_pitch_radius_mm=10.0,
      friction_coeff=0.15,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let lock_l = @worm.worm_gear_layout(lock_p)
  assert_eq(lock_l.reduction_ratio, 30.0)
  assert_eq(lock_l.center_distance_mm, 40.0)
  assert_true(lock_l.is_self_locking)
  assert_true(lock_l.efficiency > 0.3 && lock_l.efficiency < 0.5)
  // 4-start worm: tan(gamma) = 0.40 > mu=0.15 => NOT self-locking (backdrivable).
  let fast_p = match @worm.WormGearParams::new(worm_starts=4) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let fast_l = @worm.worm_gear_layout(fast_p)
  assert_false(fast_l.is_self_locking)
  assert_true(fast_l.efficiency > 0.65)
}

///|
test "worm_gear_drive compiles to valid STEP with orthogonal connectors" {
  let params = match @worm.WormGearParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let comp = match @worm.worm_gear_drive(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = comp.connectors().map(fn(c) { c.name })
  assert_true(names.contains("worm-input"))
  assert_true(names.contains("wheel-output"))
  let step_text = comp.to_design().to_step_file()
  assert_true(step_text.contains("ISO-10303-21;"))
  assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
}
