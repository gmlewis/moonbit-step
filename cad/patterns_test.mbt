///|
test "PointPattern2D ring, rect, grid, line, and combinators" {
  let r = @cad.PointPattern2D::ring(4, diam_mm=20.0)
  assert_eq(r.length(), 4)
  assert_true((r.points[0].0 - 10.0).abs() < 1.0e-9)
  assert_true(r.points[0].1.abs() < 1.0e-9)
  assert_true(r.points[1].0.abs() < 1.0e-9)
  assert_true((r.points[1].1 - 10.0).abs() < 1.0e-9)

  let rc = @cad.PointPattern2D::rect(32.0, 32.0)
  assert_eq(rc.length(), 4)
  assert_true((rc.points[0].0 - 16.0).abs() < 1.0e-9)
  assert_true((rc.points[0].1 + 16.0).abs() < 1.0e-9)

  let g = @cad.PointPattern2D::grid(3, 2, 10.0, 8.0)
  assert_eq(g.length(), 6)
  assert_true((g.points[0].0 + 10.0).abs() < 1.0e-9)
  assert_true((g.points[0].1 + 4.0).abs() < 1.0e-9)

  let ln = @cad.PointPattern2D::line(3, 15.0)
  assert_eq(ln.length(), 3)
  assert_true((ln.points[0].0 + 15.0).abs() < 1.0e-9)
  assert_true(ln.points[1].0.abs() < 1.0e-9)
  assert_true((ln.points[2].0 - 15.0).abs() < 1.0e-9)

  let shifted = r.translate(5.0, -3.0)
  assert_true((shifted.points[0].0 - 15.0).abs() < 1.0e-9)
  assert_true((shifted.points[0].1 + 3.0).abs() < 1.0e-9)

  let combined = r.combine(rc)
  assert_eq(combined.length(), 8)
}

///|
async test "PointPattern2D::drill_holes evaluates cleanly with OCCT" {
  let plate = @cad.Cylinder::new(25.0, 6.0).with_name("plate")
  let pat = @cad.PointPattern2D::ring(4, diam_mm=30.0)
  let drilled = pat.drill_holes(plate, 4.4, z0_mm=-0.5, depth_mm=7.0)
  let step = @cad.Design::new(name="pattern-drill-test")
    .add(drilled)
    .to_step_evaluated()
  assert_true(step.contains("ISO-10303-21;"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}
