///|
test "edge_loop to_step" {
  let e58 = @step.Ref::{ id: @step.EntityId::{ value: 58 } }
  let e59 = @step.Ref::{ id: @step.EntityId::{ value: 59 } }
  let e60 = @step.Ref::{ id: @step.EntityId::{ value: 60 } }
  let e61 = @step.Ref::{ id: @step.EntityId::{ value: 61 } }
  let entity = EdgeLoop::new("", [e58, e59, e60, e61])
  inspect(entity.to_step(), content="EDGE_LOOP('',(#58,#59,#60,#61))")
}
