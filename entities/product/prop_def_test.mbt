///|
test "property_definition to_step" {
  let def = @step.Ref::{ id: @step.EntityId::{ value: 1652 } }
  let entity = PropertyDefinition::new(
    "material property", "material name", def,
  )
  inspect(
    entity.to_step(),
    content="PROPERTY_DEFINITION('material property','material name',#1652)",
  )
}
