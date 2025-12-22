///|
test "SurfaceOfRevolution::to_step" {
  let curve = @step.Ref::{ id: { value: 10 } }
  let axis = @step.Ref::{ id: { value: 20 } }
  let surf = SurfaceOfRevolution::new("test", curve, axis)
  inspect(
    @step.Entity::to_step(surf),
    content="SURFACE_OF_REVOLUTION('test',#10,#20)",
  )
}
