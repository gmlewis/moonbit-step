///|
test "RepresentationRelationshipWithTransformation to_step" {
  let e = RepresentationRelationshipWithTransformation::new(@step.Ref::{
    id: @step.EntityId::{ value: 435 },
  })
  inspect(
    @step.Entity::to_step(e),
    content="REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(#435)",
  )
}
