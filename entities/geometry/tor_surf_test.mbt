///|
test "toroidal_surface to_step" {
  let pos = @step.Ref::{ id: @step.EntityId::{ value: 98 } }
  let entity = ToroidalSurface::new("", pos, "0.4", "0.4")
  inspect(entity.to_step(), content="TOROIDAL_SURFACE('',#98,0.4,0.4)")
}
