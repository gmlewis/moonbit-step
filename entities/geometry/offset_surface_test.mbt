///|
test "OffsetSurface::to_step" {
  let basis = @step.Ref::{ id: { value: 10 } }
  let surf = OffsetSurface::new("test", basis, 5.0, false)
  let s = @step.Entity::to_step(surf)
  inspect(s, content="OFFSET_SURFACE('test',#10,5.0,.F.)")
}
