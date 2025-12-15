///|
test "rational_b_spline_curve_to_step" {
  let c = RationalBSplineCurve::new(["1.", "0.5", "2."])
  inspect(
    @step.Entity::to_step(c),
    content="RATIONAL_B_SPLINE_CURVE((1.,0.5,2.))",
  )
}
