///|
// Corpus smoke test: ensure all fixture STEP files parse and become stable
// after one normalization pass (parse -> to_step_file -> parse -> to_step_file).

async test "fixtures_corpus_roundtrip_is_stable" {
  let fixtures = [
    "tests/testdata/ap242-min.step", "tests/testdata/ap242-stress.step", "tests/testdata/ap242-comments.step",
    "tests/testdata/ap242-strings.step", "tests/testdata/simple-box.step", "tests/testdata/kicadoutput01.step",
  ]
  for i = 0; i < fixtures.length(); i = i + 1 {
    let path = fixtures[i]
    let repo1 = @parse.parse_repository_from_file(path) catch {
      @parse.StepParseError(info) =>
        fail("fixture parse failed: " + @parse.format_step_parse_error(info))
      _ => fail("fixture parse failed: unexpected error")
    }
    let out1 = repo1.to_step_file()
    let repo2 = @parse.parse_repository_from_string(out1) catch {
      @parse.StepParseError(info) =>
        fail("fixture re-parse failed: " + @parse.format_step_parse_error(info))
    }
    let out2 = repo2.to_step_file()
    assert_eq(out1, out2)
  }
}
