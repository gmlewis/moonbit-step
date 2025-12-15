///|
test "dimensional_exponents_to_step" {
  let d = DimensionalExponents::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  inspect(
    @step.Entity::to_step(d),
    content="DIMENSIONAL_EXPONENTS(0.0,0.0,0.0,0.0,0.0,0.0,0.0)",
  )
}
