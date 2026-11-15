///|
test "imported STEP seeds the output and bakes the scene placement" {
  let source = @cad.Design::new(name="source")
    .add(@cad.Cuboid::new(10.0, 10.0, 10.0).with_name("vendor-block"))
    .to_step_file()
  let imported = match @cad.ImportedStep::from_string(source, source="test") {
    Ok(imported) => imported
    Err(_) => fail("could not parse the generated STEP source")
  }
  let (sx0, sx1, sy0, sy1, sz0, sz1) = imported.bounding_box()
  assert_true(sx0 < sx1)
  assert_true(sy0 < sy1)
  assert_true(sz0 < sz1)
  // Place the imported solid at x = 10 and check the baked bbox.
  let node = imported.as_shape().with_name("moteus-board").translate(x=10.0)
  let placed = imported.transformed(@cad.Transform::from_node(node))
  let (x0, x1, _, _, _, _) = placed.bounding_box()
  assert_true((x0 - 10.0).abs() < 1.0e-9)
  assert_true((x1 - 20.0).abs() < 1.0e-9)
  // The design emits the imported product plus its own context entities.
  let design = @cad.Design::new(name="imported").add(node)
  assert_true(!design.has_errors())
  let out = design.to_step_file()
  assert_true(out.contains("ISO-10303-21;"))
  assert_true(out.contains("MANIFOLD_SOLID_BREP"))
  assert_true(out.contains("vendor-block"))
}

///|
test "ImportedStep::renamed rewrites product names" {
  let source = @cad.Design::new(name="source")
    .add(@cad.Cuboid::new(5.0, 5.0, 5.0).with_name("vendor-block"))
    .to_step_file()
  assert_true(source.contains("vendor-block"))
  let imported = match @cad.ImportedStep::from_string(source, source="test") {
    Ok(imported) => imported
    Err(_) => fail("could not parse the generated STEP source")
  }
  let renamed = imported.renamed("my_part")
  let design = @cad.Design::new(name="imported").add(
    renamed.as_shape().with_name("my_part"),
  )
  assert_true(!design.has_errors())
  let out = design.to_step_file()
  assert_true(out.contains("my_part"))
  assert_true(!out.contains("PRODUCT('vendor-block'"))
  assert_true(out.contains("PRODUCT('my_part'"))
}

///|
test "multiple imported STEP files merge into one design" {
  let a = @cad.Design::new(name="a")
    .add(@cad.Cuboid::new(5.0, 5.0, 5.0).with_name("box-a"))
    .to_step_file()
  let b = @cad.Design::new(name="b")
    .add(@cad.Cylinder::new(4.0, 8.0).with_name("cyl-b"))
    .to_step_file()
  let ia = match @cad.ImportedStep::from_string(a, source="a") {
    Ok(v) => v
    Err(_) => fail("could not parse a")
  }
  let ib = match @cad.ImportedStep::from_string(b, source="b") {
    Ok(v) => v
    Err(_) => fail("could not parse b")
  }
  let design = @cad.Design::new(name="merged")
    .add(ia.as_shape().with_name("a"))
    .add(ib.as_shape().with_name("b").translate(x=20.0))
  assert_true(!design.has_errors())
  let out = design.to_step_file()
  // Both imported solids plus the output survive a round-trip parse.
  let rt = match @cad.ImportedStep::from_string(out, source="roundtrip") {
    Ok(v) => v
    Err(_) => fail("merged output does not re-parse")
  }
  let (x0, x1, _, y1, _, z1) = rt.bounding_box()
  assert_true((x0 - 0.0).abs() < 1.0e-6)
  assert_true((x1 - 22.0).abs() < 1.0e-6)
  assert_true((y1 - 5.0).abs() < 1.0e-6)
  assert_true((z1 - 8.0).abs() < 1.0e-6)
}
