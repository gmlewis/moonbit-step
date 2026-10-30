///|
/// White-box tests for the shared example output helper.

///|
fn sample_design() -> @cad.Design {
  @cad.Design::new(name="cube").add(
    @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("cube"),
  )
}

///|
fn make_paths(
  step? : String,
  blend? : String,
  bpy? : String,
  gltf? : String,
  nostep? : Bool,
) -> OutputPaths {
  OutputPaths::{ step, blend, bpy, gltf, nostep: nostep.unwrap_or(false), }
}

///|
test "output priority is blend > bpy > gltf > step" {
  // Nothing requested: the default is STEP on stdout.
  assert_true(select_output(make_paths()) is WriteStep)

  // A single requested format wins over the default.
  assert_true(select_output(make_paths(blend="a.blend")) is WriteBlend)
  assert_true(select_output(make_paths(bpy="a.py")) is WriteBpy)
  assert_true(select_output(make_paths(gltf="a.gltf")) is WriteGltf)
  assert_true(select_output(make_paths(step="a.step")) is WriteStep)

  // Priority order is blend > bpy > gltf > step.
  let all = make_paths(
    step="a.step",
    blend="a.blend",
    bpy="a.py",
    gltf="a.gltf",
  )
  assert_true(select_output(all) is WriteBlend)
  let bpy_and_gltf = make_paths(step="a.step", bpy="a.py", gltf="a.gltf")
  assert_true(select_output(bpy_and_gltf) is WriteBpy)
  let gltf_and_step = make_paths(step="a.step", gltf="a.gltf")
  assert_true(select_output(gltf_and_step) is WriteGltf)

  // --nostep overrides everything.
  let none = make_paths(
    step="a.step",
    blend="a.blend",
    bpy="a.py",
    gltf="a.gltf",
    nostep=true,
  )
  assert_true(select_output(none) is WriteNothing)
  assert_true(select_output(make_paths(nostep=true)) is WriteNothing)
}

///|
test "with_output_args adds only requested options" {
  let all = with_output_args(Map([]))
  inspect(all.length(), content="4")
  assert_true(all.get("blend") is Some(_))
  assert_true(all.get("bpy") is Some(_))
  assert_true(all.get("gltf") is Some(_))
  assert_true(all.get("out") is Some(_))
  assert_true(all.get("nostep") is None)

  let step_only = with_output_args(Map([]), blend=false, bpy=false, gltf=false)
  inspect(step_only.length(), content="1")
  assert_true(step_only.get("out") is Some(_))

  let no_gltf = with_output_args(Map([]), gltf=false)
  inspect(no_gltf.length(), content="3")
  assert_true(no_gltf.get("gltf") is None)

  let with_nostep = with_output_args(Map([]), nostep=true)
  inspect(with_nostep.length(), content="5")
  assert_true(with_nostep.get("nostep") is Some(_))

  // Existing options are preserved.
  let existing = with_output_args(
    { "edge": @cli.opt_double(20.0) },
    blend=false,
    bpy=false,
    gltf=false,
  )
  inspect(existing.length(), content="2")
  assert_true(existing.get("edge") is Some(_))
}

///|
async test "output_paths reads parsed args" {
  let spec = with_output_args(Map([]), nostep=true)
  guard @cli.parse(spec, prog="t", cli_args=[
      "--out", "a.step", "--gltf", "b.gltf", "--nostep",
    ])
    is Some(args) else {
    fail("failed to parse args")
  }
  let paths = output_paths(args)
  assert_true(paths.step == Some("a.step"))
  assert_true(paths.gltf == Some("b.gltf"))
  assert_true(paths.blend is None)
  assert_true(paths.bpy is None)
  assert_true(paths.nostep)
}

///|
async test "output_paths defaults to step on stdout" {
  // An empty cli_args means "use the real argv", so pass "--" to mean
  // "no options" explicitly.
  guard @cli.parse(with_output_args(Map([])), prog="t", cli_args=["--"])
    is Some(args) else {
    fail("failed to parse args")
  }
  let paths = output_paths(args)
  assert_true(paths.step is None)
  assert_true(paths.blend is None)
  assert_true(paths.bpy is None)
  assert_true(paths.gltf is None)
  assert_true(!paths.nostep)
  assert_true(select_output(paths) is WriteStep)
}

///|
async test "write_output writes step" {
  let dir = @fs.tmpdir(prefix="output-step")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.step"
  write_output(sample_design(), make_paths(step=path))
  let text = @fs.read_file(path).text()
  assert_true(text.has_prefix("ISO-10303-21;"))
}

///|
async test "write_output overwrites an existing file" {
  let dir = @fs.tmpdir(prefix="output-overwrite")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.step"
  // Repeated runs must replace the old output rather than leave it stale.
  @fs.write_file(path, b"stale", permission=0o644)
  write_output(sample_design(), make_paths(step=path))
  let text = @fs.read_file(path).text()
  assert_true(text.has_prefix("ISO-10303-21;"))
}

///|
async test "write_output writes gltf" {
  let dir = @fs.tmpdir(prefix="output-gltf")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.gltf"
  write_output(sample_design(), make_paths(gltf=path))
  let text = @fs.read_file(path).text()
  let doc = @json.parse(text) catch { _ => fail("invalid glTF JSON") }
  match doc {
    Object(obj) =>
      match obj.get("meshes") {
        Some(Array(meshes)) => {
          inspect(meshes.length(), content="1")
          match meshes[0] {
            Object(mesh) =>
              assert_true(mesh.get("primitives") is Some(Array(_)))
            _ => fail("mesh is not a JSON object")
          }
        }
        _ => fail("glTF has no meshes array")
      }
    _ => fail("glTF root is not a JSON object")
  }
}

///|
async test "write_output writes bpy" {
  let dir = @fs.tmpdir(prefix="output-bpy")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.py"
  write_output(sample_design(), make_paths(bpy=path))
  let text = @fs.read_file(path).text()
  assert_true(text.contains("import bpy"))
}

///|
async test "nostep writes nothing" {
  let dir = @fs.tmpdir(prefix="output-none")
  defer @fs.rmdir(dir, recursive=true)
  write_output(sample_design(), make_paths(step=dir + "/out.step", nostep=true))
  inspect(@fs.readdir(dir).length(), content="0")
}

///|
async fn blender_available() -> Bool {
  let candidates : Array[String] = [
    "/Applications/Blender.app/Contents/MacOS/Blender", "/usr/local/bin/blender",
    "/opt/homebrew/bin/blender",
  ]
  match @env.get_env_var("PATH") {
    Some(path) =>
      for dir in path.split(":").collect() {
        let dir = dir.to_owned()
        if !dir.is_empty() {
          candidates.push(dir + "/blender")
        }
      }
    None => ()
  }
  for candidate in candidates {
    if @fs.exists(candidate) {
      return true
    }
  }
  false
}

///|
async test "write_output writes blend when Blender is available" {
  // Skipped (no assertion) when Blender is not installed.
  if !blender_available() {
    return
  }
  let dir = @fs.tmpdir(prefix="output-blend")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/out.blend"
  write_output(sample_design(), make_paths(blend=path))
  assert_true(@fs.exists(path))
}
