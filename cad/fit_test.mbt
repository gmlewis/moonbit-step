///|
test "fit values are per face" {
  let fits : Array[(@cad.Fit, Double)] = [
    (Nominal, 0.0),
    (Close, 0.10),
    (Free, 0.25),
    (Press, -0.05),
  ]
  for pair in fits {
    let (fit, expected) = pair
    assert_true((fit.per_face_mm() - expected).abs() < 1.0e-12)
  }
}

///|
test "free fit grows the hole radius" {
  let pts = @cad.Profile2D::circle_with_fit(10.0, fit=Free)
  for p in pts {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    assert_true((r - 5.25).abs() < 1.0e-9)
  }
}

///|
test "press fit shrinks the hole" {
  let pts = @cad.Profile2D::circle_with_fit(10.0, fit=Press)
  for p in pts {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    assert_true((r - 4.95).abs() < 1.0e-9)
  }
}

///|
test "nominal fit equals circle" {
  assert_eq(
    @cad.Profile2D::circle_with_fit(10.0, fit=Nominal),
    @cad.Profile2D::circle(10.0),
  )
}

///|
test "hole_with_fit winds clockwise" {
  let hole = @cad.Profile2D::hole_with_fit(10.0, fit=Free)
  assert_true(@cad.polygon_area_2d(hole) < 0.0)
}

///|
test "extruded plate with a fitted hole has an inner cap bound" {
  let plate = @cad.Profile2D::rect(40.0, 20.0)
  let hole = @cad.Profile2D::hole_with_fit(10.0, fit=Free)
  let step = @cad.Design::new(name="fitted-plate")
    .add(@cad.ExtrudedProfile::new(plate, 5.0, holes=[hole]).with_name("plate"))
    .to_step_file()
  assert_true(step.contains("CLOSED_SHELL"))
  // One inner bound on each cap (bottom and top); side faces use outer bounds.
  inspect(step.split("FACE_BOUND(").count() - 1, content="2")
}
