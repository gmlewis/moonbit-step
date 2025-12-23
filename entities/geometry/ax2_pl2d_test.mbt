///|
test "Axis2Placement2D::to_step" {
  let loc = @step.Ref::{ id: { value: 10 } }
  let ax = Axis2Placement2D::new("test", loc)
  inspect(@step.Entity::to_step(ax), content="AXIS2_PLACEMENT_2D('test',#10,$)")
  let dir = @step.Ref::{ id: { value: 20 } }
  let ax2 = Axis2Placement2D::new("test2", loc, ref_direction=Some(dir))
  inspect(
    @step.Entity::to_step(ax2),
    content="AXIS2_PLACEMENT_2D('test2',#10,#20)",
  )
}
