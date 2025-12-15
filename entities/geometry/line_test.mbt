///|
test "line_to_step" {
  let p_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 160 } }
  let v_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 114 } }
  let l = Line::new("", p_ref, v_ref)
  inspect(@step.Entity::to_step(l), content="LINE('',#160,#114)")
}
