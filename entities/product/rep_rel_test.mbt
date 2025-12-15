///|
test "RepresentationRelationship to_step" {
  let e = RepresentationRelationship::new(
    "",
    "",
    @step.Ref::{ id: @step.EntityId::{ value: 40 } },
    @step.Ref::{ id: @step.EntityId::{ value: 10 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="REPRESENTATION_RELATIONSHIP('','',#40,#10)",
  )
}
