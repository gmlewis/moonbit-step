///|
test "BSplineCurve::to_step" {
  let cps = [@step.Ref::{ id: { value: 10 } }, @step.Ref::{ id: { value: 11 } }]
  let curve = BSplineCurve::new("test", 1, cps, ".UNSPECIFIED.", false, false)
  let s = @step.Entity::to_step(curve)
  inspect(s, content="B_SPLINE_CURVE('test',1,(#10,#11),.UNSPECIFIED.,.F.,.F.)")
}
