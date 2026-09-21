///|
test "Product to_step" {
  let e = @product.Product::new("cube", "cube", " ", [
    @step.Ref::{ id: @step.EntityId::{ value: 19, }, },
  ])
  inspect(@step.Entity::to_step(e), content="PRODUCT('cube','cube',' ',(#19))")
}
