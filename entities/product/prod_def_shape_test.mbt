///|
test "ProductDefinitionShape to_step" {
  let e = ProductDefinitionShape::new("", "", @step.Ref::{
    id: @step.EntityId::{ value: 14 },
  })
  inspect(
    @step.Entity::to_step(e),
    content="PRODUCT_DEFINITION_SHAPE('','',#14)",
  )
}
