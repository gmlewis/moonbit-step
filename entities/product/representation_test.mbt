///|
test "representation to_step" {
  let item = @step.Ref::{ id: @step.EntityId::{ value: 595 } }
  let ctx = @step.Ref::{ id: @step.EntityId::{ value: 1642 } }
  let entity = Representation::new("material name", [item], ctx)
  inspect(
    entity.to_step(),
    content="REPRESENTATION('material name',(#595),#1642)",
  )
}
