///|
/// Black-box tests for the OCCT-backed evaluated CSG export.
///
/// The integration test is skipped (returns early) when OCCT or `python3` is
/// not installed, mirroring `scripts/csg_eval_test.py`'s `HAVE_DRAW` guard.

///|
/// command_in_path reports whether `name` is an executable reachable through
/// `$PATH`.
async fn command_in_path(name : String) -> Bool {
  let path = @env.get_env_var("PATH").unwrap_or("")
  for dir in path.split(":").collect() {
    let dir = dir.to_owned()
    if !dir.is_empty() && @fs.exists(dir + "/" + name) {
      return true
    }
  }
  false
}

///|
async fn draw_available() -> Bool {
  command_in_path("DRAWEXE") || command_in_path("occt-draw")
}

///|
/// repo_root returns the checkout root for tests: `$MOONBIT_STEP_ROOT` if set,
/// otherwise the current working directory (moon test runs from the root).
fn repo_root() -> String raise {
  match @env.get_env_var("MOONBIT_STEP_ROOT") {
    Some(root) => root
    None =>
      match @env.current_dir() {
        Some(dir) => dir
        None => fail("cannot determine the current directory")
      }
  }
}

///|
test "csg eval script path resolves from a repository root" {
  inspect(
    @cad.csg_eval_script_path(Some("/repo")),
    content="/repo/scripts/csg_eval.py",
  )
  inspect(
    @cad.csg_eval_script_path(Some("/repo/")),
    content="/repo/scripts/csg_eval.py",
  )
  inspect(@cad.csg_eval_script_path(None), content="./scripts/csg_eval.py")
}

///|
async test "find csg eval script honours the repository root" {
  let dir = @fs.tmpdir(prefix="csg-find-")
  defer @fs.rmdir(dir, recursive=true)
  assert_true(@cad.find_csg_eval_script(Some(dir)) is None)
  @fs.mkdir(dir + "/scripts", recursive=true)
  @fs.write_file(dir + "/scripts/csg_eval.py", b"", permission=0o644)
  let found = @cad.find_csg_eval_script(Some(dir))
  assert_true(found == Some(dir + "/scripts/csg_eval.py"))
}

///|
/// eval_error captures the message raised by a failing evaluated export.
async fn eval_error(design : @cad.Design, root : String) -> String {
  try {
    let _ = design.to_step_evaluated(root=Some(root))
    fail("expected to_step_evaluated to raise CsgEvalError")
  } catch {
    @cad.CsgEvalError(msg) => msg
    e => fail("unexpected error: \{e}")
  }
}

///|
/// write_fake_evaluator installs a Python script at <root>/scripts/csg_eval.py
/// that exits with `code`.
async fn write_fake_evaluator(root : String, code : Int32) -> Unit {
  @fs.mkdir(root + "/scripts", recursive=true)
  let source =
    $|import sys
    $|print("error: neither occt-draw nor DRAWEXE is on PATH", file=sys.stderr)
    $|sys.exit(\{code})
    $|
  @fs.write_file(
    root + "/scripts/csg_eval.py",
    @encoding/utf8.encode(source),
    permission=0o644,
  )
}

///|
fn cut_design() -> @cad.Design {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cylinder::new(6.0, 10.0)
    .with_name("hole")
    .translate(x=10.0, y=10.0, z=-2.0)
  @cad.Design::new(name="cut").add(@cad.difference(base, [cutter], name="cut"))
}

///|
async test "evaluated export reports a missing evaluator script" {
  let dir = @fs.tmpdir(prefix="csg-missing-")
  defer @fs.rmdir(dir, recursive=true)
  let msg = eval_error(cut_design(), dir)
  assert_true(msg.contains("not found"))
  assert_true(msg.contains("csg_eval.py"))
}

///|
async test "evaluated export reports a clear failure when OCCT is missing" {
  if !command_in_path("python3") {
    return
  }
  let dir = @fs.tmpdir(prefix="csg-fail-")
  defer @fs.rmdir(dir, recursive=true)
  write_fake_evaluator(dir, 1)
  let msg = eval_error(cut_design(), dir)
  assert_true(msg.contains("CSG evaluation failed"))
  assert_true(msg.contains("DRAWEXE") || msg.contains("occt-draw"))
}

///|
async test "evaluated export writes a real trimmed brep" {
  if !command_in_path("python3") || !draw_available() {
    return
  }
  let root = repo_root()
  let dir = @fs.tmpdir(prefix="csg-eval-")
  defer @fs.rmdir(dir, recursive=true)
  let out = dir + "/evaluated.step"
  cut_design().write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("MANIFOLD_SOLID_BREP"))
  assert_false(text.contains("BOOLEAN_RESULT("))
  assert_false(text.contains("CSG_SOLID("))
  // The evaluated file must pass the structural validator.
  let (code, output) = run_validator([
    root + "/scripts/validate_step.py",
    "--no-mesh",
    out,
  ])
  assert_validator_ok(code, output)
}

///|
test "flat writer refuses edge fillet with a typed diagnostic" {
  let base = @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("block")
  let design = @cad.Design::new(name="fillet-flat").add(
    @cad.fillet_edges(base, 2.0, name="rounded-block"),
  )
  let diags = design.diagnostics()
  assert_true(diags.any(fn(d) { d is @cad.EdgeFeatureRequiresKernel(_) }))
  assert_true(design.has_errors())
  let messages = diags.map(fn(d) { d.message() }).join(" ")
  assert_true(messages.contains("rounded-block"))
  assert_true(messages.contains("evaluated"))
  // The intent carries the fillet radius and selector.
  match @cad.fillet_edges(base, 2.0).shape {
    @cad.Shape::Fillet(f) => {
      assert_true(f.size_mm == 2.0)
      assert_true(f.selector is @cad.EdgeSelector::AllEdges)
    }
    _ => abort("expected a Fillet shape")
  }
}

///|
test "flat writer refuses edge chamfer with a typed diagnostic" {
  let base = @cad.Cylinder::new(10.0, 8.0).with_name("cyl")
  let design = @cad.Design::new(name="chamfer-flat").add(
    @cad.chamfer_edges(
      base,
      1.0,
      selector=@cad.EdgeSelector::EdgesNearPoint((0.0, 0.0, 8.0), 1.0),
    ),
  )
  assert_true(
    design.diagnostics().any(fn(d) { d is @cad.EdgeFeatureRequiresKernel(_) }),
  )
  assert_true(design.has_errors())
}

///|
async test "evaluated fillet yields a valid solid with a toroidal face" {
  if !command_in_path("python3") || !draw_available() {
    return
  }
  let root = repo_root()
  let dir = @fs.tmpdir(prefix="edge-fillet-")
  defer @fs.rmdir(dir, recursive=true)
  let base = @cad.Cylinder::new(10.0, 8.0).with_name("cyl")
  let design = @cad.Design::new(name="fillet-eval").add(
    @cad.fillet_edges(
      base,
      1.0,
      selector=@cad.EdgeSelector::EdgesNearPoint((0.0, 0.0, 8.0), 1.0),
      name="top-fillet",
    ),
  )
  let out = dir + "/fillet.step"
  design.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("TOROIDAL_SURFACE"))
  let (code, output) = run_validator([
    root + "/scripts/validate_step.py",
    "--no-mesh",
    out,
  ])
  assert_validator_ok(code, output)
}

///|
async test "evaluated chamfer yields a valid solid with a conical face" {
  if !command_in_path("python3") || !draw_available() {
    return
  }
  let root = repo_root()
  let dir = @fs.tmpdir(prefix="edge-chamfer-")
  defer @fs.rmdir(dir, recursive=true)
  let base = @cad.Cylinder::new(10.0, 8.0).with_name("cyl")
  let design = @cad.Design::new(name="chamfer-eval").add(
    @cad.chamfer_edges(
      base,
      1.0,
      selector=@cad.EdgeSelector::EdgesNearPoint((0.0, 0.0, 8.0), 1.0),
      name="top-chamfer",
    ),
  )
  let out = dir + "/chamfer.step"
  design.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("CONICAL_SURFACE"))
  let (code, output) = run_validator([
    root + "/scripts/validate_step.py",
    "--no-mesh",
    out,
  ])
  assert_validator_ok(code, output)
}

///|
async test "evaluated multi-edge chamfer targets perpendicular cap edges" {
  if !command_in_path("python3") || !draw_available() {
    return
  }
  let root = repo_root()
  let dir = @fs.tmpdir(prefix="edge-chamfer-multi-")
  defer @fs.rmdir(dir, recursive=true)
  let base = @cad.Cylinder::new(10.0, 8.0).with_name("cyl")
  let design = @cad.Design::new(name="chamfer-multi-eval").add(
    @cad.chamfer_edges(
      base,
      0.5,
      selector=@cad.EdgeSelector::EdgesPerpendicularToDirection(
        (0.0, 0.0, 1.0),
        1.0,
      ),
      name="cap-chamfers",
    ),
  )
  let out = dir + "/chamfer-multi.step"
  design.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("CONICAL_SURFACE"))
  let (code, output) = run_validator([
    root + "/scripts/validate_step.py",
    "--no-mesh",
    out,
  ])
  assert_validator_ok(code, output)
}

///|
/// json_member returns an object member, or JSON null when absent.
fn ev_json_member(j : @json.Json, key : String) -> @json.Json {
  match j {
    Object(m) =>
      match m.get(key) {
        Some(v) => v
        None => @json.Json::null()
      }
    _ => @json.Json::null()
  }
}

///|
fn ev_json_number(j : @json.Json, key : String) -> Double {
  match ev_json_member(j, key) {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
fn ev_json_array(j : @json.Json, key : String) -> Array[@json.Json] {
  match ev_json_member(j, key) {
    Array(a) => a
    _ => []
  }
}

///|
fn ev_json_item_number(j : @json.Json) -> Double {
  match j {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
async test "evaluated counterbored plate is one watertight solid" {
  if !command_in_path("python3") || !draw_available() {
    return
  }
  let root = repo_root()
  let dir = @fs.tmpdir(prefix="csg-plate-")
  defer @fs.rmdir(dir, recursive=true)
  let plate = @cad.Cuboid::new(50.0, 40.0, 8.0).with_name("plate")
  let through = @cad.Cylinder::new(5.5, 20.0)
    .with_name("through")
    .translate(x=25.0, y=20.0, z=-6.0)
  let cbore = @cad.Cylinder::new(9.0, 2.0)
    .with_name("counterbore")
    .translate(x=25.0, y=20.0, z=6.0)
  let design = @cad.Design::new(name="counterbored-plate").add(
    @cad.difference(plate, [through, cbore], name="counterbored-plate"),
  )
  let out = dir + "/plate.step"
  design.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("MANIFOLD_SOLID_BREP"))
  assert_false(text.contains("BOOLEAN_RESULT("))
  assert_false(text.contains("CSG_SOLID("))
  // Full validator, including watertight tessellation.
  let (code, output) = run_validator([root + "/scripts/validate_step.py", out])
  assert_validator_ok(code, output)
  assert_true(output.contains("1 solids, 1 closed shells"))
  assert_true(output.contains("[PASS] occt mesh"))
  // Measure the evaluated solid.
  let (mcode, mdata) = @process.collect_output_merged("python3", [
    root + "/scripts/measure_step_occt.py",
    out,
  ])
  assert_true(mcode == 0)
  let mout = mdata.text()
  let doc = @json.parse(mout) catch { _ => fail("invalid measurement JSON") }
  assert_true(ev_json_number(doc, "solids") == 1.0)
  // 50*40*8 - pi*2.75^2*8 - pi*(4.5^2-2.75^2)*2 = 15730.216 mm^3.
  assert_true((ev_json_number(doc, "volume") - 15730.216).abs() < 0.5)
  let bbox = ev_json_array(doc, "bbox")
  assert_eq(bbox.length(), 6)
  let extents : Array[Double] = [
    ev_json_item_number(bbox[1]) - ev_json_item_number(bbox[0]),
    ev_json_item_number(bbox[3]) - ev_json_item_number(bbox[2]),
    ev_json_item_number(bbox[5]) - ev_json_item_number(bbox[4]),
  ]
  assert_true((extents[0] - 50.0).abs() < 0.01)
  assert_true((extents[1] - 40.0).abs() < 0.01)
  assert_true((extents[2] - 8.0).abs() < 0.01)
}
