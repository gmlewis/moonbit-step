///|
fn straight_anchor(x : Double, y : Double) -> BezierAnchor {
  { position: (x, y), handle_in: (x, y), handle_out: (x, y), }
}

///|
fn straight_square(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  clear~ : Bool,
) -> BezierPath {
  {
    anchors: [
      straight_anchor(x0, y0),
      straight_anchor(x1, y0),
      straight_anchor(x1, y1),
      straight_anchor(x0, y1),
    ],
    closed: true,
    clear,
  }
}

///|
test "extruded bezier profile emits a closed shell" {
  let outer = straight_square(0.0, 0.0, 10.0, 10.0, clear=false)
  let hole = straight_square(4.0, 4.0, 6.0, 6.0, clear=true)
  let step = Design::new(name="bezier-plate")
    .add(ExtrudedBezierProfile::new([outer, hole], 2.0).with_name("plate"))
    .to_step_file()
  // A compiled glyph must never wrap an empty shell.
  assert_false(step.contains("CLOSED_SHELL('',())"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  // Two caps plus four side faces per loop.
  let face_count = step.split("ADVANCED_FACE(").count() - 1
  inspect(face_count, content="10")
}
