///|
test "context_dependent_shape_representation to_step" {
  let rr = @step.Ref::{ id: @step.EntityId::{ value: 434 } }
  let rpr = @step.Ref::{ id: @step.EntityId::{ value: 436 } }
  let entity = ContextDependentShapeRepresentation::new(rr, rpr)
  inspect(
    entity.to_step(),
    content="CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(#434,#436)",
  )
}
