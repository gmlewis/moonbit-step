///|
// AP242 comment-handling fixture.
// Ensures /* ... */ comments don't affect parsing/idempotence.

async test "ap242_comments_fixture_roundtrip_is_idempotent" {
  let repo1 = @parse.parse_repository_from_file(
    "tests/testdata/ap242-comments.step",
  )
  let out1 = repo1.to_step_file()
  let repo2 = @parse.parse_repository_from_string(out1)
  let out2 = repo2.to_step_file()
  assert_eq(out1, out2)
  assert_true(out2.contains("AP242_MANAGED_MODEL_BASED_3D_ENGINEERING_MIM_LF"))
  // Comment stripping may introduce additional whitespace; avoid exact-match.
  assert_true(out2.contains("#5=FOO_BAR("))
  assert_true(out2.contains("'X'"))
}
