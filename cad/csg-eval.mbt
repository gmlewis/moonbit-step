///|
// OCCT-backed evaluated export of nominal booleans.
//
// `to_csg_step` already emits a real boolean tree (`CSG_SOLID` wrapping
// `BOOLEAN_RESULT` nodes), but OCCT's STEP reader cannot consume that tree.
// `scripts/csg_eval.py` loads each leaf B-Rep, folds the tree with
// `bfuse`/`bcut`/`bcommon`, and writes a flat, trimmed B-Rep. This module
// wires that development-time tool into the async export flow.
//
// The library itself stays kernel-free: the Python script and OCCT are
// optional runtime tools. When either is missing the evaluated export fails
// with an explicit message; the nominal STEP paths are unchanged.

///|
/// CsgEvalError reports why an evaluated CSG export could not be produced.
pub suberror CsgEvalError {
  CsgEvalError(String)
}

///|
/// csg_eval_script_path joins a repository root with `scripts/csg_eval.py`.
///
/// A `None` root falls back to the current-directory relative path, matching
/// the Blender exporter's script resolution.
pub fn csg_eval_script_path(root : String?) -> String {
  match root {
    Some(r) =>
      if r.has_suffix("/") {
        r + "scripts/csg_eval.py"
      } else {
        r + "/scripts/csg_eval.py"
      }
    None => "./scripts/csg_eval.py"
  }
}

///|
/// find_csg_eval_script resolves `$MOONBIT_STEP_ROOT` (falling back to
/// `./scripts/csg_eval.py`) and returns the path only when it exists.
pub async fn find_csg_eval_script(root : String?) -> String? {
  let path = csg_eval_script_path(root)
  if @fs.exists(path) {
    Some(path)
  } else {
    None
  }
}

///|
/// Design::to_step_evaluated evaluates the design's boolean tree with OCCT and
/// returns the resulting flat, trimmed B-Rep STEP document.
///
/// It writes `to_csg_step()` to a temporary file, runs
/// `python3 scripts/csg_eval.py` with `$MOONBIT_STEP_ROOT` (or `root`), and
/// reads back the evaluated STEP. Raises `CsgEvalError` when the script is
/// missing or OCCT fails.
pub async fn Design::to_step_evaluated(
  self : Design,
  root~ : String? = None,
) -> String {
  let root = match root {
    Some(_) => root
    None => @env.get_env_var("MOONBIT_STEP_ROOT")
  }
  let script = match find_csg_eval_script(root) {
    Some(path) => path
    None =>
      raise CsgEvalError(
        "cannot evaluate CSG booleans: '\{csg_eval_script_path(root)}' not found. Set MOONBIT_STEP_ROOT to the repository root (or run from it). OCCT's occt-draw or DRAWEXE is also required.",
      )
  }
  let temp_dir = @fs.tmpdir(prefix="moonbit-csg-eval-")
  defer @fs.rmdir(temp_dir, recursive=true)
  let input_path = temp_dir + "/input.step"
  let output_path = temp_dir + "/evaluated.step"
  write_text_file(self.to_csg_step(), Some(input_path))
  // Capture the evaluator's output instead of inheriting stdout: callers may
  // be tests that talk a structured protocol on stdout.
  let (code, output) = @process.collect_output_merged("python3", [
    script, input_path, "-o", output_path,
  ])
  if code != 0 {
    raise CsgEvalError(
      "CSG evaluation failed (scripts/csg_eval.py exited with status \{code}): \{output.text()}. Evaluating booleans requires Open CASCADE ('occt-draw' or 'DRAWEXE' on PATH) and a design with a boolean tree.",
    )
  }
  if !@fs.exists(output_path) {
    raise CsgEvalError(
      "CSG evaluation finished but wrote no output to '\{output_path}'.",
    )
  }
  @fs.read_file(output_path).text()
}

///|
/// Design::write_step_evaluated writes the OCCT-evaluated STEP document to
/// `out_path` (or stdout). Aborts with the evaluator's message on failure.
pub async fn Design::write_step_evaluated(
  self : Design,
  out_path : String?,
  root~ : String? = None,
) -> Unit {
  let text = self.to_step_evaluated(root~) catch {
    CsgEvalError(msg) => abort(msg)
    err => abort("CSG evaluation failed: \{err}")
  }
  write_text_file(text, out_path)
}
