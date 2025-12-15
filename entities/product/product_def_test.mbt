///|
test "ProductDefinition to_step" {
  let e = ProductDefinition::new(
    " ",
    "",
    @step.Ref::{ id: @step.EntityId::{ value: 16 } },
    @step.Ref::{ id: @step.EntityId::{ value: 15 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_DEFINITION(' ','',#16,#15)",
  )
}
