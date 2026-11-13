///|
/// Black-box integration test for the clamp shaft collar's evaluated solid.
///
/// Skipped when `python3` or OCCT is not installed, matching the
/// `cad/csg-eval_test.mbt` guard. The flat writer cannot trim the radial slit
/// or the clamp-screw holes, so the evaluated solid is the artifact compared
/// against the CC0 reference.

///|
async fn csc_command_in_path(name : String) -> Bool {
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
async fn csc_draw_available() -> Bool {
  csc_command_in_path("DRAWEXE") || csc_command_in_path("occt-draw")
}

///|
fn csc_repo_root() -> String raise {
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
fn csc_json_member(j : @json.Json, key : String) -> @json.Json {
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
fn csc_json_number(j : @json.Json, key : String) -> Double {
  match csc_json_member(j, key) {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
fn csc_json_array(j : @json.Json, key : String) -> Array[@json.Json] {
  match csc_json_member(j, key) {
    Array(a) => a
    _ => []
  }
}

///|
fn csc_json_item_number(j : @json.Json) -> Double {
  match j {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
async test "clamp collar evaluates to one trimmed solid" {
  if !csc_command_in_path("python3") || !csc_draw_available() {
    return
  }
  let root = csc_repo_root()
  let dir = @fs.tmpdir(prefix="clamp-collar-eval-")
  defer @fs.rmdir(dir, recursive=true)
  let part = match
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, screw_offset_mm=14.73) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // The default export is nominal; the evaluated export is the artifact.
  let out = dir + "/collar.step"
  part.write_step_evaluated(Some(out), root=Some(root))
  let text = @fs.read_file(out).text()
  assert_true(text.contains("MANIFOLD_SOLID_BREP"))
  assert_false(text.contains("BOOLEAN_RESULT("))
  assert_false(text.contains("CSG_SOLID("))
  // The evaluator restores per-solid presentation colours when OCP is
  // available; without OCP the geometry is unchanged but uncoloured.
  let (ocolor, _) = @process.collect_output_merged("python3", [
    "-c", "import OCP",
  ])
  if ocolor == 0 {
    assert_true(text.contains("COLOUR_RGB"))
  }
  let (vcode, vout) = @process.collect_output_merged("python3", [
    root + "/scripts/validate_step.py",
    out,
  ])
  assert_true(vcode == 0)
  let vtext = vout.text()
  assert_true(vtext.contains("1 solids, 1 closed shells"))
  assert_true(vtext.contains("[PASS] occt mesh"))
  let (mcode, mout) = @process.collect_output_merged("python3", [
    root + "/scripts/measure_step_occt.py",
    out,
  ])
  assert_true(mcode == 0)
  let doc = @json.parse(mout.text()) catch {
    _ => fail("invalid measurement JSON")
  }
  assert_true(csc_json_number(doc, "solids") == 1.0)
  let bbox = csc_json_array(doc, "bbox")
  assert_eq(bbox.length(), 6)
  let extents : Array[Double] = [
    csc_json_item_number(bbox[1]) - csc_json_item_number(bbox[0]),
    csc_json_item_number(bbox[3]) - csc_json_item_number(bbox[2]),
    csc_json_item_number(bbox[5]) - csc_json_item_number(bbox[4]),
  ]
  assert_true((extents[0] - 40.0).abs() < 0.02)
  // The slit removes the extreme +Y point, so the outside extent is
  // sqrt(20^2 - 0.4^2) = 19.996 on each side.
  assert_true((extents[1] - 39.996).abs() < 0.02)
  assert_true((extents[2] - 15.0).abs() < 0.02)
  // The analytic body is the chamfered annulus minus the slit and the clamp
  // holes. The measured volume is checked against the reference body's
  // 12955.6 mm^3 within 1%: the slit, clearance passage, and counterbore are
  // the same geometry.
  assert_true((csc_json_number(doc, "volume") - 12955.6).abs() < 130.0)
}
