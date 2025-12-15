///|
test "ProductDefinitionContext to_step" {
  let e = ProductDefinitionContext::new(
    "part definition",
    @step.Ref::{ id: @step.EntityId::{ value: 21 } },
    "design",
  )
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_DEFINITION_CONTEXT('part definition',#21,'design')",
  )
}
