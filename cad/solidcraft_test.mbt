///|
test "Design::to_solidcraft_script emits native box/cylinder/combine commands" {
  let bolts = @cad.PointPattern2D::ring(4, diam_mm=24.0)
  let part = @cad.Cylinder::new(18.0, 6.0)
    .with_name("plate")
    .with_color(@cad.Rgb::blue())
    .drill(bolts, 3.4, depth_mm=8.0)
  let sc = @cad.Design::new(name="bolt_plate")
    .add(part)
    .to_solidcraft_script(leaves_dir="/tmp/sc-test-leaves")
  assert_eq(sc.leaf_files.length(), 0)
  assert_true(sc.script_json.contains("\"file.new\""))
  assert_true(sc.script_json.contains("\"solid.cylinder\""))
  assert_true(sc.script_json.contains("\"solid.combine\""))
  assert_true(sc.script_json.contains("\"cut\""))
  assert_true(sc.script_json.contains("\"appearance.assign\""))
  // Verify valid JSON
  let _ = @json.parse(sc.script_json)
}

///|
test "Design::to_solidcraft_script emits leaf STEP for RevolvedProfile" {
  let puck = @cad.RevolvedProfile::chamfered_cylinder(
      30.0,
      8.0,
      bottom_chamfer=0.35,
    )
    .as_shape()
    .with_name("puck")
  let sc = @cad.Design::new(name="revolved_puck")
    .add(puck)
    .to_solidcraft_script(leaves_dir="/tmp/sc-rev-leaves")
  assert_eq(sc.leaf_files.length(), 1)
  assert_true(sc.script_json.contains("\"file.insert_step\""))
  let _ = @json.parse(sc.script_json)
}
