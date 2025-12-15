///|
test "b_spline_surface_to_step" {
  let s = BSplineSurface::new(
    2,
    2,
    [
      [
        @step.Ref::{ id: @step.EntityId::{ value: 1 } },
        @step.Ref::{ id: @step.EntityId::{ value: 2 } },
      ],
      [
        @step.Ref::{ id: @step.EntityId::{ value: 3 } },
        @step.Ref::{ id: @step.EntityId::{ value: 4 } },
      ],
    ],
    ".UNSPECIFIED.",
    false,
    false,
    false,
  )
  inspect(
    @step.Entity::to_step(s),
    content="B_SPLINE_SURFACE(2,2,((#1,#2),(#3,#4)),.UNSPECIFIED.,.F.,.F.,.F.)",
  )
}
