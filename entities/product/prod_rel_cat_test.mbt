///|
test "ProductRelatedProductCategory to_step" {
  let e = ProductRelatedProductCategory::new("part", "", [
    @step.Ref::{ id: @step.EntityId::{ value: 18 } },
  ])
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_RELATED_PRODUCT_CATEGORY('part','',(#18))",
  )
}
