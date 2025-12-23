///|
test "CompositeCurveSegment::to_step" {
  let curve = @step.Ref::{ id: { value: 10 } }
  let seg = CompositeCurveSegment::new(Continuous, true, curve)
  inspect(
    @step.Entity::to_step(seg),
    content="COMPOSITE_CURVE_SEGMENT(.CONTINUOUS.,.T.,#10)",
  )
}

///|
test "CompositeCurve::to_step" {
  let segs = [
    @step.Ref::{ id: { value: 10 } },
    @step.Ref::{ id: { value: 20 } },
  ]
  let curve = CompositeCurve::new("test", segs, false)
  inspect(
    @step.Entity::to_step(curve),
    content="COMPOSITE_CURVE('test',(#10,#20),.F.)",
  )
}

///|
test "TransitionCode::to_step" {
  inspect(
    @step.Entity::to_step(TransitionCode::Discontinuous),
    content=".DISCONTINUOUS.",
  )
  inspect(
    @step.Entity::to_step(TransitionCode::Continuous),
    content=".CONTINUOUS.",
  )
  inspect(
    @step.Entity::to_step(TransitionCode::ContSameGradient),
    content=".CONTSAMEGRADIENT.",
  )
  inspect(
    @step.Entity::to_step(TransitionCode::ContSameGradientSameCurvature),
    content=".CONTSAMEGRADIENTSAMECURVATURE.",
  )
}
