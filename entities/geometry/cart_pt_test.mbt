///|
test "cartesian_point_to_step" {
  let p = CartesianPoint::new("CP1", [1.0, 2.0, 3.0])
  inspect(
    @step.Entity::to_step(p),
    content="CARTESIAN_POINT('CP1',(1.0,2.0,3.0))",
  )
}
