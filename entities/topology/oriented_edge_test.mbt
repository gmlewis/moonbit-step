///|
test "oriented_edge to_step" {
  let edge_element = @step.Ref::{ id: @step.EntityId::{ value: 90 } }
  let entity = OrientedEdge::new("", "*", "*", edge_element, true)
  inspect(entity.to_step(), content="ORIENTED_EDGE('',*,*,#90,.T.)")
}
