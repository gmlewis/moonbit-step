///|
fn near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-12
}

///|
test "unit conversions" {
  assert_true(near(@cad.Length::inches(1.0).to_mm(), 25.4))
  assert_true(near(@cad.Length::cm(2.5).to_mm(), 25.0))
  assert_true(near(@cad.Length::m(0.001).to_mm(), 1.0))
  assert_true(near(@cad.Length::mm(7.0).to_mm(), 7.0))
}

///|
test "length arithmetic" {
  let a = @cad.Length::mm(10.0)
  let b = @cad.Length::cm(2.0)
  assert_true(near((a + b).to_mm(), 30.0))
  assert_true(near((a - b).to_mm(), -10.0))
  assert_true(near((-a).to_mm(), -10.0))
  assert_true(near(a.scale(2.5).to_mm(), 25.0))
}

///|
test "angle conversions" {
  assert_true(near(@cad.Angle::deg(180.0).to_rad(), 3.141592653589793))
  assert_true(near(@cad.Angle::rad(3.141592653589793).to_deg(), 180.0))
  assert_true(near(@cad.Angle::deg(90.0).to_rad(), 1.5707963267948966))
}

///|
test "cuboid from lengths emits millimetre geometry" {
  let shape = @cad.Cuboid::from_lengths(
    lx=@cad.Length::mm(20.0),
    ly=@cad.Length::cm(1.0),
    lz=@cad.Length::mm(5.0),
  )
  let (x0, x1, y0, y1, z0, z1) = shape.bounding_box()
  assert_true(near(x0, 0.0))
  assert_true(near(x1, 20.0))
  assert_true(near(y0, 0.0))
  assert_true(near(y1, 10.0))
  assert_true(near(z0, 0.0))
  assert_true(near(z1, 5.0))
  let step = @cad.Design::new(name="lengths")
    .add(shape.with_name("box"))
    .to_step_file()
  assert_true(step.contains("CARTESIAN_POINT('',(20.0,0.0,0.0))"))
}
