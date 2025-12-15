///|
test "conical_surface to_step" {
  let pos = @step.Ref::{ id: @step.EntityId::{ value: 611 } }
  let entity = ConicalSurface::new(
    "", pos, "0.3500599520011", "0.140686945962564",
  )
  inspect(
    entity.to_step(),
    content="CONICAL_SURFACE('',#611,0.3500599520011,0.140686945962564)",
  )
}
