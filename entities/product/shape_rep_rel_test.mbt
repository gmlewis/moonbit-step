///|
test "ShapeRepresentationRelationship to_step" {
  let e = ShapeRepresentationRelationship::new(
    "None",
    "relationship between cube-None and cube-None",
    @step.Ref::{ id: @step.EntityId::{ value: 22 } },
    @step.Ref::{ id: @step.EntityId::{ value: 11 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="SHAPE_REPRESENTATION_RELATIONSHIP('None','relationship between cube-None and cube-None',#22,#11)",
  )
}
