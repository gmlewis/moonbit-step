///|
async test "ap242_min_fixture_roundtrip_is_idempotent" {
  let repo1 = @parse.parse_repository_from_file("tests/testdata/ap242-min.step")
  let out1 = repo1.to_step_file()

  // Parsing our own output should produce the exact same output again.
  let repo2 = @parse.parse_repository_from_string(out1)
  let out2 = repo2.to_step_file()
  assert_true(out1 == out2)

  // Also ensure unknown DATA entities survive the roundtrip.
  assert_true(out2.contains("#10=FOO_BAR(1,$,'X');"))
}
