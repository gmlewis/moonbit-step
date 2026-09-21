///|
test "vector_to_step" {
  let d_ref : @step.Ref = @step.Ref::{ id: @step.EntityId::{ value: 135, }, }
  let v = @geometry.Vector::new("", d_ref, 1.0)
  inspect(@step.Entity::to_step(v), content="VECTOR('',#135,1.0)")
}
