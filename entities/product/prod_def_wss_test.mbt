///|
test "ProductDefinitionFormationWithSpecifiedSource to_step" {
  let e = @product.ProductDefinitionFormationWithSpecifiedSource::new(
    " ",
    " ",
    @step.Ref::{ id: @step.EntityId::{ value: 18, }, },
    ".NOT_KNOWN.",
  )
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE(' ',' ',#18,.NOT_KNOWN.)",
  )
}
