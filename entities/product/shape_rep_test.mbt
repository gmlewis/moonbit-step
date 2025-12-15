///|
test "ShapeRepresentation to_step" {
  let e = ShapeRepresentation::new(
    "cube-None",
    [@step.Ref::{ id: @step.EntityId::{ value: 126 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 187 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="SHAPE_REPRESENTATION('cube-None',(#126),#187)",
  )
}
