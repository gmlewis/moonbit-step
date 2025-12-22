///|
test "OffsetCurve3D::to_step" {
  let basis = @step.Ref::{ id: { value: 10 } }
  let dir = @step.Ref::{ id: { value: 20 } }
  let curve = OffsetCurve3D::new("test", basis, 5.0, dir)
  let s = @step.Entity::to_step(curve)
  inspect(s, content="OFFSET_CURVE_3D('test',#10,5.0,#20)")
}
