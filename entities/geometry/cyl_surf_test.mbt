///|
test "cylindrical_surface to_step" {
  let pos = @step.Ref::{ id: @step.EntityId::{ value: 602 } }
  let entity = CylindricalSurface::new("", pos, "0.435")
  inspect(entity.to_step(), content="CYLINDRICAL_SURFACE('',#602,0.435)")
}
