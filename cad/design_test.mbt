///|
test "design bounding box unions every node" {
  let empty = @cad.Design::new()
  assert_eq(empty.bounding_box(), (0.0, 0.0, 0.0, 0.0, 0.0, 0.0))

  let one = @cad.Design::new().add(
    @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("a"),
  )
  let (x0, x1, y0, y1, z0, z1) = one.bounding_box()
  assert_true(x0.abs() < 1.0e-9)
  assert_true((x1 - 10.0).abs() < 1.0e-9)
  assert_true(y0.abs() < 1.0e-9)
  assert_true((y1 - 10.0).abs() < 1.0e-9)
  assert_true(z0.abs() < 1.0e-9)
  assert_true((z1 - 10.0).abs() < 1.0e-9)

  let two = @cad.Design::new()
    .add(@cad.Cuboid::new(10.0, 10.0, 10.0).with_name("a"))
    .add(@cad.Cuboid::new(10.0, 10.0, 10.0).with_name("b").translate(x=30.0))
  let (x0, x1, _y0, _y1, _z0, _z1) = two.bounding_box()
  assert_true(x0.abs() < 1.0e-9)
  assert_true((x1 - 40.0).abs() < 1.0e-9)
}
