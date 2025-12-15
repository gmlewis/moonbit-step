///|
test "ProductContext to_step" {
  let e = ProductContext::new(
    " ",
    @step.Ref::{ id: @step.EntityId::{ value: 21 } },
    "mechanical",
  )
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_CONTEXT(' ',#21,'mechanical')",
  )
}
