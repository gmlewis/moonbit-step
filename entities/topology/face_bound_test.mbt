///|
test "face_bound to_step" {
  let b = @step.Ref::{ id: @step.EntityId::{ value: 158 } }
  let entity = FaceBound::new("", b, true)
  inspect(entity.to_step(), content="FACE_BOUND('',#158,.T.)")
}
