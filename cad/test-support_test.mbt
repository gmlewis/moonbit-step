///|
/// Shared helpers for black-box tests that shell out to the repository's
/// Python tooling.

///|
/// run_validator runs `python3` on the given arguments and captures its
/// output. The test driver owns stdout, so a child writing to an inherited
/// stdout would corrupt its event protocol.
async fn run_validator(args : Array[String]) -> (Int32, String) {
  let (code, output) = @process.collect_output_merged("python3", args)
  (code, output.text())
}

///|
/// assert_validator_ok fails with the validator's captured output.
fn assert_validator_ok(code : Int32, output : String) -> Unit raise {
  if code != 0 {
    fail("scripts/validate_step.py exited with status \{code}:\n\{output}")
  }
}
