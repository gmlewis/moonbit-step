///|
test "edge_curve to_step" {
  let start = @step.Ref::{ id: @step.EntityId::{ value: 82 } }
  let end = @step.Ref::{ id: @step.EntityId::{ value: 83 } }
  let geom = @step.Ref::{ id: @step.EntityId::{ value: 102 } }
  let entity = EdgeCurve::new("", start, end, geom, true)
  inspect(entity.to_step(), content="EDGE_CURVE('',#82,#83,#102,.T.)")
}
