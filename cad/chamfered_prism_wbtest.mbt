///|
fn count_sub(haystack : String, needle : String) -> Int32 {
  haystack.split(needle).collect().length() - 1
}

///|
test "square prism with a top chamfer is watertight and planar" {
  let prism = ChamferedPrism::from_chamfer(
    Profile2D::rect(10.0, 10.0),
    5.0,
    top_chamfer=1.0,
    chamfer_depth=1.0,
  )
  inspect(prism.validate() is Ok(_), content="true")
  let shape = Shape::ChamferedPrism(prism)
  let (x0, x1, y0, y1, z0, z1) = shape.bounding_box()
  assert_true((x0 - 0.0).abs() < 1.0e-9)
  assert_true((x1 - 10.0).abs() < 1.0e-9)
  assert_true((y1 - 10.0).abs() < 1.0e-9)
  assert_true((z1 - 5.0).abs() < 1.0e-9)
  let step = Design::new(name="prism")
    .add(shape.with_name("prism"))
    .to_step_file()
  // 2 caps + 2 bands * 4 quads = 10 planar faces.
  assert_eq(count_sub(step, "ADVANCED_FACE("), 10)
  assert_eq(count_sub(step, "PLANE("), 10)
}

///|
test "hex prism with a round through-hole has annular caps and hole walls" {
  let hex = Profile2D::polygon(6, 10.0, rotation=30.0)
  let hole = Profile2D::circle(4.0, segments=32).rev()
  let prism = ChamferedPrism::from_chamfer(
    hex,
    6.0,
    bottom_chamfer=0.5,
    top_chamfer=0.5,
    chamfer_depth=0.6,
    hole~,
  )
  inspect(prism.validate() is Ok(_), content="true")
  let step = Design::new(name="nut")
    .add(Shape::ChamferedPrism(prism).with_name("nut"))
    .to_step_file()
  // Caps with holes plus walls, all planar.
  assert_true(count_sub(step, "ADVANCED_FACE(") > 20)
  assert_eq(count_sub(step, "CYLINDRICAL_SURFACE("), 0)
}

///|
test "chamfered prism rejects an inset that collapses the base" {
  let prism = ChamferedPrism::from_chamfer(
    Profile2D::rect(2.0, 2.0),
    3.0,
    top_chamfer=2.0,
    chamfer_depth=0.5,
  )
  inspect(prism.validate() is Err(_), content="true")
}
