///|
test "axis2_placement_3d_to_step" {
  let p_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 10 } }
  let d1_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 11 } }
  let d2_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 12 } }
  let a2p3d = Axis2Placement3D::new("A2P3D", p_ref, d1_ref, d2_ref)
  inspect(
    @step.Entity::to_step(a2p3d),
    content="AXIS2_PLACEMENT_3D('A2P3D',#10, #11, #12)",
  )
}
