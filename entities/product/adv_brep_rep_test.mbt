///|
test "AdvancedBrepShapeRepresentation to_step" {
  let e = AdvancedBrepShapeRepresentation::new(
    "cube-None",
    [@step.Ref::{ id: @step.EntityId::{ value: 32 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 187 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="ADVANCED_BREP_SHAPE_REPRESENTATION('cube-None',(#32),#187)",
  )
}
