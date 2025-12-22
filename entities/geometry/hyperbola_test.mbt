///|
test "Hyperbola::to_step" {
  let pos = @step.Ref::{ id: { value: 10 } }
  let hyperbola = Hyperbola::new("test", pos, 10.0, 5.0)
  let s = @step.Entity::to_step(hyperbola)
  inspect(s, content="HYPERBOLA('test',#10,10.0,5.0)")
}
