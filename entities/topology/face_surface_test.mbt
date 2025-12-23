///|
test "FaceSurface::to_step" {
  let bounds = [@step.Ref::{ id: { value: 10 } }]
  let geom = @step.Ref::{ id: { value: 20 } }
  let face = FaceSurface::new("test", bounds, geom, true)
  let s = @step.Entity::to_step(face)
  inspect(s, content="FACE_SURFACE('test',(#10),#20,.T.)")
}
