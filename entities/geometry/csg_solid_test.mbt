///|
test "CsgSolid::to_step" {
  let root = @step.Ref::{ id: { value: 10 } }
  let solid = CsgSolid::new("test-solid", root)
  let s = @step.Entity::to_step(solid)
  inspect(s, content="CSG_SOLID('test-solid',#10)")
}
