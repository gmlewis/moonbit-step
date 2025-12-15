///|
test "b_spline_curve_with_knots to_step" {
  let cp1 = @step.Ref::{ id: @step.EntityId::{ value: 10 } }
  let cp2 = @step.Ref::{ id: @step.EntityId::{ value: 11 } }
  let cp3 = @step.Ref::{ id: @step.EntityId::{ value: 12 } }
  let cp4 = @step.Ref::{ id: @step.EntityId::{ value: 13 } }
  let entity = BSplineCurveWithKnots::new(
    "",
    3,
    [cp1, cp2, cp3, cp4],
    ".UNSPECIFIED.",
    false,
    false,
    [4, 4],
    ["0.", "1."],
    ".UNSPECIFIED.",
  )
  inspect(
    entity.to_step(),
    content="B_SPLINE_CURVE_WITH_KNOTS('',3,(#10,#11,#12,#13),.UNSPECIFIED.,.F.,.F.,(4,4),(0.,1.),.UNSPECIFIED.)",
  )
}
