///|
test "SurfaceOfLinearExtrusion::to_step" {
  let curve = @step.Ref::{ id: { value: 10 } }
  let axis = @step.Ref::{ id: { value: 20 } }
  let surf = SurfaceOfLinearExtrusion::new("test", curve, axis)
  let s = @step.Entity::to_step(surf)
  inspect(s, content="SURFACE_OF_LINEAR_EXTRUSION('test',#10,#20)")
}
