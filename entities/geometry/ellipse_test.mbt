///|
test "ellipse to_step" {
  let pos = @step.Ref::{ id: @step.EntityId::{ value: 613 } }
  let entity = Ellipse::new("", pos, "0.123303040813508", "0.117733653429061")
  inspect(
    entity.to_step(),
    content="ELLIPSE('',#613,0.123303040813508,0.117733653429061)",
  )
}
