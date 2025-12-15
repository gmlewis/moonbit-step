///|
test "product_definition_formation to_step" {
  let prod = @step.Ref::{ id: @step.EntityId::{ value: 1658 } }
  let entity = ProductDefinitionFormation::new("", "$", prod)
  inspect(entity.to_step(), content="PRODUCT_DEFINITION_FORMATION('',$,#1658)")
}
