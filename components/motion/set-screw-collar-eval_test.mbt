///|
/// Black-box integration test for the set-screw shaft collar's evaluated solid.
///
/// The test is skipped (returns early) when `python3` or OCCT is not installed,
/// matching the `cad/csg-eval_test.mbt` guard. The flat writer cannot trim the
/// radial hole, so this is the artifact compared against the CC0 reference.

///|
async fn ssc_command_in_path(name : String) -> Bool {
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
async fn ssc_draw_available() -> Bool {
  ssc_command_in_path("DRAWEXE") || ssc_command_in_path("occt-draw")
}

///|
fn ssc_repo_root() -> String raise {
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
fn ssc_json_member(j : @json.Json, key : String) -> @json.Json {
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
fn ssc_json_number(j : @json.Json, key : String) -> Double {
  match ssc_json_member(j, key) {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
fn ssc_json_array(j : @json.Json, key : String) -> Array[@json.Json] {
  match ssc_json_member(j, key) {
    Array(a) => a
    _ => []
  }
}

///|
fn ssc_json_item_number(j : @json.Json) -> Double {
  match j {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
async test "set-screw collar evaluates to one trimmed solid" {
  if !ssc_command_in_path("python3") || !ssc_draw_available() {
    return
  }
  let root = ssc_repo_root()
  let dir = @fs.tmpdir(prefix="set-screw-collar-eval-")
  defer @fs.rmdir(dir, recursive=true)
  let part = match @motion.set_screw_shaft_collar(8.0, 16.0, 8.0) {
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
  assert_true(ssc_json_number(doc, "solids") == 1.0)
  let bbox = ssc_json_array(doc, "bbox")
  assert_eq(bbox.length(), 6)
  let extents : Array[Double] = [
    ssc_json_item_number(bbox[1]) - ssc_json_item_number(bbox[0]),
    ssc_json_item_number(bbox[3]) - ssc_json_item_number(bbox[2]),
    ssc_json_item_number(bbox[5]) - ssc_json_item_number(bbox[4]),
  ]
  assert_true((extents[0] - 16.0).abs() < 0.01)
  assert_true((extents[1] - 16.0).abs() < 0.01)
  assert_true((extents[2] - 8.0).abs() < 0.01)
  // The chamfered annulus minus the radial tap-drill hole. The analytic base
  // volume comes from the same revolved profile; the hole is pi r^2 * wall,
  // whose curved-wall correction is under 1 mm^3 at these dimensions.
  let base = @cad.RevolvedProfile::chamfered_tube(
    16.0,
    8.0,
    8.0,
    outer_bottom_chamfer=0.2,
    outer_top_chamfer=0.2,
    inner_bottom_chamfer=0.2,
    inner_top_chamfer=0.2,
  ).as_shape()
  let base_volume = match base.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let drill = 4.1339746
  let hole_volume = @math.PI * (drill / 2.0) * (drill / 2.0) * 4.0
  let expected = base_volume - hole_volume
  assert_true((ssc_json_number(doc, "volume") - expected).abs() < 1.5)
}
