///|
test "rational_b_spline_surface_to_step" {
  let s = RationalBSplineSurface::new([
    ["1.", "0.5", "2."],
    ["0.25", "1.", "0.25"],
  ])
  inspect(
    @step.Entity::to_step(s),
    content="RATIONAL_B_SPLINE_SURFACE(((1.,0.5,2.),(0.25,1.,0.25)))",
  )
}
