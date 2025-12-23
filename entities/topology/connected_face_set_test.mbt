///|
test "ConnectedFaceSet::to_step" {
  let faces = [
    @step.Ref::{ id: { value: 10 } },
    @step.Ref::{ id: { value: 20 } },
  ]
  let cfs = ConnectedFaceSet::new("test", faces)
  let s = @step.Entity::to_step(cfs)
  inspect(s, content="CONNECTED_FACE_SET('test',(#10,#20))")
}
