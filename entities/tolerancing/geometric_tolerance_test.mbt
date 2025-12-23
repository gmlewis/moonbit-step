///|
test "GeometricTolerance::to_step" {
  let mag = @step.Ref::{ id: { value: 10 } }
  let shape = @step.Ref::{ id: { value: 20 } }
  let gt = GeometricTolerance::new("name", "desc", mag, shape)
  inspect(
    @step.Entity::to_step(gt),
    content="GEOMETRIC_TOLERANCE('name','desc',#10,#20)",
  )
}
