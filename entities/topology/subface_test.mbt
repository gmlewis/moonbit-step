///|
test "Subface::to_step" {
  let bounds = [@step.Ref::{ id: { value: 10 } }]
  let parent = @step.Ref::{ id: { value: 20 } }
  let face = Subface::new("test", bounds, parent)
  let s = @step.Entity::to_step(face)
  inspect(s, content="SUBFACE('test',(#10),#20)")
}
