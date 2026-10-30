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
  let code = @process.run(
    "python3",
    [root + "/scripts/validate_step.py", "--no-mesh", out],
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  inspect(code, content="0")
}
