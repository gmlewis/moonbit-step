///|
test "vertex_point to_step" {
  let geom = @step.Ref::{ id: @step.EntityId::{ value: 161 } }
  let entity = VertexPoint::new("", geom)
  inspect(entity.to_step(), content="VERTEX_POINT('',#161)")
}
