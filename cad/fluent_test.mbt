///|
test "PointPattern2D::to_arc_holes builds exact analytic ExtrudedArcProfile" {
  let bolts = @cad.PointPattern2D::ring(4, diam_mm=30.0)
  let prof = @cad.ExtrudedArcProfile::new(
    @cad.arc_circle_loop(0.0, 0.0, 46.0),
    6.0,
    round_bore=((0.0, 0.0), 8.0),
  ).with_pattern_holes(bolts, 4.5)
  assert_true(prof.validate())
  let vol = match prof.as_shape().analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = (
      @math.PI * 23.0 * 23.0 -
      @math.PI * 4.0 * 4.0 -
      4.0 * @math.PI * 2.25 * 2.25
    ) *
    6.0
  assert_true((vol - expected).abs() < 1.0e-3)
  let step = @cad.Design::new(name="analytic_flange")
    .add(prof.as_shape().with_name("flange"))
    .to_step_file()
  assert_true(step.contains("CLOSED_SHELL("))
  assert_true(step.contains("CYLINDRICAL_SURFACE("))
}

///|
test "Plate::round without chamfers uses zero-boolean analytic profile" {
  let holes = @cad.PointPattern2D::ring(6, diam_mm=34.0)
  let node = @cad.Plate::round(
      outer_diam_mm=46.0,
      thickness_mm=8.0,
      name="output_flange",
    )
    .with_bore(8.2)
    .with_holes(holes, 4.5)
    .with_color(@cad.Rgb::blue())
    .to_node()
  assert_eq(node.name, "output_flange")
  let design = @cad.Design::new(name="round_plate").add(node)
  assert_false(design.has_errors())
  let step = design.to_step_file()
  assert_true(step.contains("CLOSED_SHELL("))
}

///|
test "Plate::rect with rounded corners and rect hole pattern is analytic" {
  let standoffs = @cad.PointPattern2D::rect(32.0, 32.0)
  let node = @cad.Plate::rect(
      width_mm=44.0,
      height_mm=44.0,
      thickness_mm=5.0,
      corner_radius_mm=4.0,
      name="moteus_plate",
    )
    .with_bore(10.0)
    .with_holes(standoffs, 3.4)
    .to_node()
  assert_eq(node.name, "moteus_plate")
  let design = @cad.Design::new(name="rect_plate").add(node)
  assert_false(design.has_errors())
  let step = design.to_step_file()
  assert_true(step.contains("CLOSED_SHELL("))
}

///|
async test "Plate::round with bottom chamfer and holes evaluates via OCCT" {
  let holes = @cad.PointPattern2D::ring(4, diam_mm=24.0)
  let node = @cad.Plate::round(
      outer_diam_mm=36.0,
      thickness_mm=6.0,
      name="chamfered_flange",
    )
    .with_bore(8.0)
    .with_chamfer(bottom_mm=0.35)
    .with_holes(holes, 3.4)
    .to_node()
  let step = @cad.Design::new(name="chamfered_plate")
    .add(node)
    .to_step_evaluated()
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}

///|
async test "SceneNode fluent drill and union_with pipeline evaluates via OCCT" {
  let boss = @cad.Cylinder::new(8.0, 12.0).with_name("boss")
  let bolts = @cad.PointPattern2D::ring(4, diam_mm=26.0)
  let part = @cad.Cylinder::new(18.0, 5.0)
    .with_name("flange")
    .with_color(@cad.Rgb::green())
    .with_bottom_chamfer(size_mm=0.35)
    .union_with(boss)
    .drill_center_bore(6.0, depth_mm=14.0)
    .drill(bolts, 3.4, depth_mm=8.0)
  assert_eq(part.name, "flange")
  let step = @cad.Design::new(name="fluent_part").add(part).to_step_evaluated()
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}
