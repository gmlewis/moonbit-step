///|
test "SweptSurface::to_step" {
  let curve = @step.Ref::{ id: { value: 10 } }
  let surf = SweptSurface::new("test", curve)
  let s = @step.Entity::to_step(surf)
  inspect(s, content="SWEPT_SURFACE('test',#10)")
}
