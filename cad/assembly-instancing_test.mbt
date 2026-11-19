///|
fn instancing_profile(radius : Double, segs : Int32) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for i in 0..<segs {
    let a = 2.0 * @math.PI * i.to_double() / segs.to_double()
    out.push((radius * @math.cos(a), radius * @math.sin(a)))
  }
  out
}

///|
/// Four translated and rotated copies of one multi-face solid.
fn instancing_design() -> @cad.Design {
  let outer = instancing_profile(20.0, 32)
  let hole = instancing_profile(6.0, 24)
  let part = @cad.ExtrudedProfile::new(outer, 10.0, holes=[hole])
  @cad.Design::new(name="instancing")
  .add(part.with_name("part-a"))
  .add(part.with_name("part-b").translate(x=50.0))
  .add(part.with_name("part-c").translate(x=50.0, y=50.0).rotate_z(90.0))
  .add(part.with_name("part-d").translate(y=50.0).rotate_z(180.0))
}

///|
test "instanced assembly shares one brep per unique part" {
  let design = instancing_design()
  let flat = design.to_step_file()
  let instanced = design.to_instanced_step_string(
    assembly_name="instancing-asm",
  )
  let legacy = design.to_assembly_step(assembly_name="instancing-asm")
  inspect(
    instanced.split("ADVANCED_BREP_SHAPE_REPRESENTATION(").count() - 1,
    content="1",
  )
  inspect(
    instanced.split("NEXT_ASSEMBLY_USAGE_OCCURRENCE(").count() - 1,
    content="4",
  )
  inspect(
    instanced.split("ITEM_DEFINED_TRANSFORMATION(").count() - 1,
    content="4",
  )
  assert_true(instanced.length() < flat.length() * 45 / 100)
  assert_true(instanced.length() < legacy.length())
}

///|
test "non-instanced assembly keeps one product per node" {
  let step = instancing_design().to_assembly_step(
    assembly_name="instancing-asm",
  )
  inspect(step.split("PRODUCT(").count() - 1, content="5")
  inspect(
    step.split("NEXT_ASSEMBLY_USAGE_OCCURRENCE(").count() - 1,
    content="4",
  )
}

///|
async test "instanced assembly renders and parses" {
  let design = instancing_design()
  let step = design.to_instanced_step_string(assembly_name="instancing-asm")
  @cad.write_text_file(step, Some("/tmp/instanced.step"))

  // The in-repo parser must round-trip the product structure.
  let repo = @parse.parse_repository_from_string(step)
  assert_true(repo.len() > 0)
  assert_true(
    repo.to_step_data_section().contains("NEXT_ASSEMBLY_USAGE_OCCURRENCE"),
  )

  // The structural validator accepts product-structure assemblies.
  let root = repo_root()
  let validator = root + "/scripts/validate_step.py"
  let (code, output) = @process.collect_output_merged("python3", [
    validator, "--no-mesh", "/tmp/instanced.step",
  ])
  if code != 0 {
    fail(output.text())
  }

  // SolidCraft expands the four instances: 4 bodies, 4x volume, correct world
  // bounding box (x 0..70, y 0..70, z 0..10 for these placements).
  if command_in_path("solidcraft-cli") {
    let (eval_code, eval_out) = @process.collect_output_merged(
      "solidcraft-cli",
      [
        "eval", "--in", "/tmp/instanced.step", "--json-out", "/tmp/instanced.json",
      ],
    )
    if eval_code != 0 {
      fail(eval_out.text())
    }
    let json = @json.parse(@fs.read_file("/tmp/instanced.json").text())
    let report = match json {
      Object(obj) => obj
      _ => fail("solidcraft-cli eval did not return a JSON object")
    }
    let bodies = match report.get("body_count") {
      Some(Number(n, ..)) => n
      _ => fail("solidcraft-cli eval JSON has no body_count")
    }
    assert_true(bodies == 4.0)
    let total = match report.get("total") {
      Some(Object(obj)) => obj
      _ => fail("solidcraft-cli eval JSON has no total")
    }
    let volume = match total.get("volume_mm3") {
      Some(Number(n, ..)) => n
      _ => fail("solidcraft-cli eval JSON has no total.volume_mm3")
    }
    // One part: (pi*20^2 - pi*6^2) * 10 ~= 11435 mm^3, faceted slightly less.
    assert_true(volume > 4.0 * 11000.0 && volume < 4.0 * 11600.0)
    let (shot_code, shot_out) = @process.collect_output_merged(
      "solidcraft-cli",
      [
        "snapshot", "--in", "/tmp/instanced.step", "--out", "/tmp/instanced.png",
        "--view", "iso", "--no-grid",
      ],
    )
    if shot_code != 0 {
      fail(shot_out.text())
    }
  }
}
