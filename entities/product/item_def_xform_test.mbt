///|
test "item_defined_transformation to_step" {
  let i1 = @step.Ref::{ id: @step.EntityId::{ value: 11 } }
  let i2 = @step.Ref::{ id: @step.EntityId::{ value: 15 } }
  let entity = ItemDefinedTransformation::new("", "", i1, i2)
  inspect(
    entity.to_step(),
    content="ITEM_DEFINED_TRANSFORMATION('','',#11,#15)",
  )
}
