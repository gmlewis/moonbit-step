///|
test "HalfSpaceSolid::to_step" {
  let surf = @step.Ref::{ id: { value: 10 } }
  let hs = HalfSpaceSolid::new("test", surf, true)
  let s = @step.Entity::to_step(hs)
  inspect(s, content="HALF_SPACE_SOLID('test',#10,.T.)")
}
