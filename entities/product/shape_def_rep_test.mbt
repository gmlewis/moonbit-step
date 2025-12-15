///|
test "ShapeDefinitionRepresentation to_step" {
  let e = ShapeDefinitionRepresentation::new(
    @step.Ref::{ id: @step.EntityId::{ value: 13 } },
    @step.Ref::{ id: @step.EntityId::{ value: 22 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="SHAPE_DEFINITION_REPRESENTATION(#13,#22)",
  )
}
