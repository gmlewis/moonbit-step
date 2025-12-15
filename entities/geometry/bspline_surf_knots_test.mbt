///|
test "b_spline_surface_with_knots_to_step" {
  let s = BSplineSurfaceWithKnots::new(
    [3, 3],
    [3, 2, 3],
    ["-0.1", "0.2"],
    ["-3.14159", "0.0", "3.14159"],
    ".UNSPECIFIED.",
  )
  inspect(
    @step.Entity::to_step(s),
    content="B_SPLINE_SURFACE_WITH_KNOTS((3,3),(3,2,3),(-0.1,0.2),(-3.14159,0.0,3.14159),.UNSPECIFIED.)",
  )
}
