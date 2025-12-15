///|
test "face_outer_bound to_step" {
  let b = @step.Ref::{ id: @step.EntityId::{ value: 52 } }
  let entity = FaceOuterBound::new("", b, true)
  inspect(entity.to_step(), content="FACE_OUTER_BOUND('',#52,.T.)")
}
