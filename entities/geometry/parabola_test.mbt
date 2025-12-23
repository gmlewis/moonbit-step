///|
test "Parabola::to_step" {
  let pos = @step.Ref::{ id: { value: 10 } }
  let parabola = Parabola::new("test", pos, 5.0)
  let s = @step.Entity::to_step(parabola)
  inspect(s, content="PARABOLA('test',#10,5.0)")
}
