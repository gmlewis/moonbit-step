///|
test "KinematicLink::to_step" {
  let link = KinematicLink::new("test link")
  inspect(@step.Entity::to_step(link), content="KINEMATIC_LINK('test link')")
}

///|
test "KinematicJoint::to_step" {
  let l1 = @step.Ref::{ id: { value: 10 } }
  let l2 = @step.Ref::{ id: { value: 20 } }
  let joint = KinematicJoint::new("test joint", l1, l2)
  inspect(
    @step.Entity::to_step(joint),
    content="KINEMATIC_JOINT('test joint',#10,#20)",
  )
}

///|
test "KinematicPair::to_step" {
  let joint = @step.Ref::{ id: { value: 10 } }
  let pair = KinematicPair::new("test pair", "desc", joint)
  inspect(
    @step.Entity::to_step(pair),
    content="KINEMATIC_PAIR('test pair','desc',#10)",
  )
}
