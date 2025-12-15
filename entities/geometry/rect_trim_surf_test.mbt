///|
test "rectangular_trimmed_surface_to_step" {
  let s = RectangularTrimmedSurface::new(
    "",
    @step.Ref::{ id: @step.EntityId::{ value: 12 } },
    "0.0",
    "1.0",
    "-0.5",
    "0.5",
    true,
    true,
  )
  inspect(
    @step.Entity::to_step(s),
    content="RECTANGULAR_TRIMMED_SURFACE('',#12,0.0,1.0,-0.5,0.5,.T.,.T.)",
  )
}
