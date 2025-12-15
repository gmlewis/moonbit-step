///|
test "trim_curve to_step" {
  let e = TrimmedCurve::new(
    "",
    @step.Ref::{ id: @step.EntityId::{ value: 12 } },
    "(PARAMETER_VALUE(0.0))",
    "(PARAMETER_VALUE(1.0))",
    true,
    ".PARAMETER.",
  )
  inspect(
    @step.Entity::to_step(e),
    content="TRIMMED_CURVE('',#12,(PARAMETER_VALUE(0.0)),(PARAMETER_VALUE(1.0)),.T.,.PARAMETER.)",
  )
}
