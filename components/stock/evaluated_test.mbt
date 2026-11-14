///|
/// Black-box test for the component-level evaluated-solid export.
///
/// The integration test is skipped (returns early) when `python3` or OCCT is
/// not installed, matching the `cad/csg-eval_test.mbt` guard.

///|
async fn evl_command_in_path(name : String) -> Bool {
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
async fn evl_draw_available() -> Bool {
  evl_command_in_path("DRAWEXE") || evl_command_in_path("occt-draw")
}

///|
fn evl_repo_root() -> String raise {
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
fn evl_json_member(j : @json.Json, key : String) -> @json.Json {
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
fn evl_json_number(j : @json.Json, key : String) -> Double {
  match evl_json_member(j, key) {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
fn evl_json_array(j : @json.Json, key : String) -> Array[@json.Json] {
  match evl_json_member(j, key) {
    Array(a) => a
    _ => []
  }
}

///|
fn evl_json_item_number(j : @json.Json) -> Double {
  match j {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
async test "counterbored plate evaluates to one watertight solid" {
  if !evl_command_in_path("python3") || !evl_draw_available() {
    return
  }
  let root = evl_repo_root()
  let dir = @fs.tmpdir(prefix="stock-eval-")
  defer @fs.rmdir(dir, recursive=true)
  let holes : Array[@stock.CounterboredHole] = [
    @stock.CounterboredHole::{
      x_mm: 0.0,
      y_mm: 0.0,
      through_diameter_mm: 5.5,
      counterbore_diameter_mm: 9.0,
      counterbore_depth_mm: 2.0,
    },
  ]
  let plate = match @stock.plate_with_counterbores(50.0, 40.0, 8.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // The default export keeps the two explicit touching layers.
  assert_eq(plate.layers().length(), 2)
  let out = dir + "/plate.step"
  plate.write_step_evaluated(Some(out), root=Some(root))
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
  assert_true(evl_json_number(doc, "solids") == 1.0)
  // 50*40*8 - pi*2.75^2*8 - pi*(4.5^2-2.75^2)*2 = 15730.216 mm^3.
  assert_true((evl_json_number(doc, "volume") - 15730.216).abs() < 0.5)
  let bbox = evl_json_array(doc, "bbox")
  assert_eq(bbox.length(), 6)
  let extents : Array[Double] = [
    evl_json_item_number(bbox[1]) - evl_json_item_number(bbox[0]),
    evl_json_item_number(bbox[3]) - evl_json_item_number(bbox[2]),
    evl_json_item_number(bbox[5]) - evl_json_item_number(bbox[4]),
  ]
  assert_true((extents[0] - 50.0).abs() < 0.01)
  assert_true((extents[1] - 40.0).abs() < 0.01)
  assert_true((extents[2] - 8.0).abs() < 0.01)
}

///|
async test "SC8UU block evaluates to one solid with five through bores" {
  if !evl_command_in_path("python3") || !evl_draw_available() {
    return
  }
  let root = evl_repo_root()
  let dir = @fs.tmpdir(prefix="sc8uu-eval-")
  defer @fs.rmdir(dir, recursive=true)
  let part = match @stock.sc8uu_bearing_block() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let out = dir + "/sc8uu.step"
  part.write_step_evaluated(Some(out), root=Some(root))
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
  assert_true(evl_json_number(doc, "solids") == 1.0)
  assert_true((evl_json_number(doc, "volume") - 16282.890747550957).abs() < 0.5)
  let bbox = evl_json_array(doc, "bbox")
  assert_eq(bbox.length(), 6)
  let extents : Array[Double] = [
    evl_json_item_number(bbox[1]) - evl_json_item_number(bbox[0]),
    evl_json_item_number(bbox[3]) - evl_json_item_number(bbox[2]),
    evl_json_item_number(bbox[5]) - evl_json_item_number(bbox[4]),
  ]
  assert_true((extents[0] - 34.0).abs() < 0.01)
  assert_true((extents[1] - 30.0).abs() < 0.01)
  assert_true((extents[2] - 22.0).abs() < 0.01)
}
