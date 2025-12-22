///|
test "Axis1Placement::to_step" {
  let loc = @step.Ref::{ id: { value: 10 } }
  let ax = Axis1Placement::new("test", loc)
  inspect(@step.Entity::to_step(ax), content="AXIS1_PLACEMENT('test',#10,$)")
  let dir = @step.Ref::{ id: { value: 20 } }
  let ax2 = Axis1Placement::new("test2", loc, axis=Some(dir))
  inspect(
    @step.Entity::to_step(ax2),
    content="AXIS1_PLACEMENT('test2',#10,#20)",
  )
}
