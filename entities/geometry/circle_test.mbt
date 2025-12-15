///|
test "circle to_step" {
  let pos = @step.Ref::{ id: @step.EntityId::{ value: 600 } }
  let entity = Circle::new("", pos, "0.435")
  inspect(entity.to_step(), content="CIRCLE('',#600,0.435)")
}
