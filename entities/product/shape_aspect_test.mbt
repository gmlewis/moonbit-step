///|
test "ShapeAspect::to_step" {
  let shape = @step.Ref::{ id: { value: 10 } }
  let sa = ShapeAspect::new("name", "desc", shape, ".T.")
  inspect(
    @step.Entity::to_step(sa),
    content="SHAPE_ASPECT('name','desc',#10,.T.)",
  )
}
