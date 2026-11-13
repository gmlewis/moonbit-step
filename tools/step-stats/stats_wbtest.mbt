///|
test "step-stats counts a synthetic STEP string" {
  let text = "ISO-10303-21;\nDATA;\n#1=CARTESIAN_POINT('',(0.,0.,0.));\n#2=CARTESIAN_POINT('',(10.,20.,30.));\n#3=DIRECTION('',(1.,0.,0.));\n#4=LINE('',#1,#3);\n#5=CIRCLE('',#1,2.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let stats = analyze_text(text, text.length())
  assert_eq(stats.cartesian_point, 2)
  assert_eq(stats.line, 1)
  assert_eq(stats.circle, 1)
  assert_eq(stats.advanced_face, 0)
  match stats.bbox {
    Some((x0, x1, _y0, y1, _z0, z1)) => {
      assert_true((x0 - 0.0).abs() < 1.0e-9)
      assert_true((x1 - 10.0).abs() < 1.0e-9)
      assert_true((y1 - 20.0).abs() < 1.0e-9)
      assert_true((z1 - 30.0).abs() < 1.0e-9)
    }
    None => abort("expected a point bounding box")
  }
}

///|
test "step-stats counts solid and surface entities" {
  let text = "ISO-10303-21;\nDATA;\n#1=MANIFOLD_SOLID_BREP('',#2);\n#2=CLOSED_SHELL('',(#3));\n#3=ADVANCED_FACE('',(#4),#5,.T.);\n#4=FACE_OUTER_BOUND('',#6,.T.);\n#5=CYLINDRICAL_SURFACE('',#7,5.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let stats = analyze_text(text, text.length())
  assert_eq(stats.manifold_solid_brep, 1)
  assert_eq(stats.closed_shell, 1)
  assert_eq(stats.advanced_face, 1)
  assert_eq(stats.cylinder, 1)
}

///|
test "step-stats reads a generated analytic cylinder" {
  // Build the cylinder in memory so the test never depends on a committed
  // example output file. Example STEP files are generated locally and are
  // intentionally not tracked in this repository.
  let body = @cad.RevolvedProfile::cylinder(10.0, 20.0)
    .as_shape()
    .with_name("body")
  let text = @cad.Design::new(name="analytic-cylinder").add(body).to_step_file()
  let stats = analyze_text(text, text.length())
  assert_eq(stats.manifold_solid_brep, 1)
  assert_eq(stats.closed_shell, 1)
  assert_eq(stats.advanced_face, 3)
  assert_eq(stats.cylinder, 1)
  assert_eq(stats.plane, 2)
  assert_true(stats.cartesian_point > 0)
}
