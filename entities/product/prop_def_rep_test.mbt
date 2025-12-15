///|
test "property_definition_representation to_step" {
  let def = @step.Ref::{ id: @step.EntityId::{ value: 596 } }
  let rep = @step.Ref::{ id: @step.EntityId::{ value: 593 } }
  let entity = PropertyDefinitionRepresentation::new(def, rep)
  inspect(
    entity.to_step(),
    content="PROPERTY_DEFINITION_REPRESENTATION(#596,#593)",
  )
}
