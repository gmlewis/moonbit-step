///|
test "bevel differential forward and inverse 2-DOF kinematics round-trip" {
  assert_true(
    @differential.BevelDifferentialParams::new(input_teeth=6) is Err(_),
  )
  let params = match
    @differential.BevelDifferentialParams::new(
      module_mm=2.0,
      input_teeth=20,
      output_teeth=30,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let layout = @differential.bevel_differential_layout(params)
  assert_true((layout.roll_ratio - 1.5).abs() < 1.0e-9)
  // Pure pitch: both motors rotate together -> roll == 0.
  let (p1, r1) = @differential.differential_forward_kinematics(layout, 1.2, 1.2)
  assert_true((p1 - 1.2).abs() < 1.0e-9)
  assert_true(r1.abs() < 1.0e-9)
  // Pure roll: motors rotate opposite -> pitch == 0.
  let (p2, r2) = @differential.differential_forward_kinematics(
    layout, 1.5, -1.5,
  )
  assert_true(p2.abs() < 1.0e-9)
  assert_true((r2 - 1.0).abs() < 1.0e-9)
  // Combined round-trip: FK(IK(pitch, roll)) == (pitch, roll).
  let (ta, tb) = @differential.differential_inverse_kinematics(
    layout, 0.7, -0.45,
  )
  let (p3, r3) = @differential.differential_forward_kinematics(layout, ta, tb)
  assert_true((p3 - 0.7).abs() < 1.0e-9)
  assert_true((r3 + 0.45).abs() < 1.0e-9)
}

///|
test "bevel_differential compiles to valid STEP with 2-DOF connectors" {
  let params = match @differential.BevelDifferentialParams::new() {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let comp = match @differential.bevel_differential(params) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = comp.connectors().map(fn(c) { c.name })
  assert_true(names.contains("motor-a-input"))
  assert_true(names.contains("motor-b-input"))
  assert_true(names.contains("output-shaft"))
  let step_text = comp.to_design().to_step_file()
  assert_true(step_text.contains("ISO-10303-21;"))
  assert_true(step_text.contains("ADVANCED_BREP_SHAPE_REPRESENTATION"))
}
