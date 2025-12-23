///|
test "DimensionalSize::to_step" {
  let sa = @step.Ref::{ id: { value: 10 } }
  let ds = DimensionalSize::new(sa, "test")
  let s = @step.Entity::to_step(ds)
  inspect(s, content="DIMENSIONAL_SIZE(#10,'test')")
}
