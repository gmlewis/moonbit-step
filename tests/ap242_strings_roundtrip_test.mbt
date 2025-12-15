///|
// AP242 string/comment edgecase fixture.
// Ensures comment stripping does not affect string literals.

async test "ap242_strings_fixture_roundtrip_is_idempotent" {
  let out1 = try {
    let repo1 = @parse.parse_repository_from_file(
      "tests/testdata/ap242-strings.step",
    )
    repo1.to_step_file()
  } catch {
    @parse.StepParseError(info) =>
      fail("StepParseError: " + @parse.format_step_parse_error(info))
    _ => fail("unexpected error while parsing ap242-strings fixture")
  }
  let repo2 = @parse.parse_repository_from_string(out1) catch {
    @parse.StepParseError(info) =>
      fail("StepParseError: " + @parse.format_step_parse_error(info))
  }
  let out2 = repo2.to_step_file()
  assert_eq(out1, out2)

  // Verify key string payloads survived.
  assert_true(out2.contains("AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF"))
  assert_true(out2.contains("/* not a comment */"))
  assert_true(out2.contains("semicolon ; inside"))
  assert_true(out2.contains("It''s fine"))
  assert_true(out2.contains("#3=FOO_BAR("))
  assert_true(out2.contains("'X;Y'"))
}
