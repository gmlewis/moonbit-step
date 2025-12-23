///|
test "Polyline::to_step" {
  let pts = [@step.Ref::{ id: { value: 10 } }, @step.Ref::{ id: { value: 20 } }]
  let poly = Polyline::new("test", pts)
  let s = @step.Entity::to_step(poly)
  inspect(s, content="POLYLINE('test',(#10,#20))")
}
