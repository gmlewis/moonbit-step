///|
// Fidelity tests for the lossless STEP parser/serializer.
//
// The older `*_roundtrip_test.mbt` files assert out1 == out2 (idempotence),
// which cannot detect first-pass data loss that happens to be idempotent.
// These tests compare serialized output against the INPUT instead.

fn fid_wrap(data : String) -> String {
  "ISO-10303-21;\n" +
  "HEADER;\n" +
  "FILE_DESCRIPTION(('fidelity'),'2;1');\n" +
  "FILE_NAME('fidelity.step','2025-01-01T00:00:00',('gmlewis/step'),('gmlewis/step'),'moon','moonbit','none');\n" +
  "FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));\n" +
  "ENDSEC;\n" +
  "DATA;\n" +
  data +
  "\n" +
  "ENDSEC;\n" +
  "END-ISO-10303-21;\n"
}

///|
fn fid_emit(input : String) -> String raise {
  match @parse.parse_repository_from_string_result(input) {
    @parse.ParseRepositoryResult::Ok(repo) => repo.to_step_file()
    @parse.ParseRepositoryResult::Err(info) =>
      fail("parse failed: " + @parse.format_step_parse_error(info))
  }
}

///|
// Re-parsing must succeed; a ParseError here means the serializer emitted
// invalid STEP text.
fn fid_reparse(text : String) -> String raise {
  match @parse.parse_repository_from_string_result(text) {
    @parse.ParseRepositoryResult::Ok(repo) => repo.to_step_file()
    @parse.ParseRepositoryResult::Err(info) =>
      fail("re-parse failed: " + @parse.format_step_parse_error(info))
  }
}

///|
// Control: unrecognized entities are already preserved verbatim.
test "unknown entity strings survive verbatim" {
  let input = fid_wrap("#3=SOME_UNKNOWN_ENTITY('Acme''s',1);")
  let out = fid_emit(input)
  assert_true(out.contains("#3=SOME_UNKNOWN_ENTITY('Acme''s',1);"))
  assert_eq(out, fid_reparse(out))
}

///|
// A doubled apostrophe in a RECOGNIZED entity must round-trip to the same
// STEP string literal, and the emitted file must be re-parseable.
test "recognized entity preserves doubled apostrophes" {
  let input = fid_wrap("#1=CARTESIAN_POINT('O''Brien',(1.,2.,3.));")
  let out = fid_emit(input)
  assert_true(out.contains("CARTESIAN_POINT('O''Brien',"))
  assert_eq(out, fid_reparse(out))
}

///|
// Multiple apostrophes exercise the escaper beyond its first match.
test "recognized entity preserves several apostrophes" {
  let input = fid_wrap("#1=CARTESIAN_POINT('O''Brien and Mary''s',(1.,2.,3.));")
  let out = fid_emit(input)
  assert_true(out.contains("'O''Brien and Mary''s'"))
  assert_eq(out, fid_reparse(out))
}

///|
// `fmt_num` deliberately rounds reals below 1e-12 to "0.0" (see
// `step-format_wbtest.mbt`). That rounding is REQUIRED for generated STEP to
// validate properly, so a third-party real such as -3.70074341541719E-015 is
// normalized by the parse -> serialize path. This is intended behavior, not a
// defect, and there is deliberately no fidelity test for it here.

///|
// parse_repository_from_file must decode UTF-8, not Latin-1 per byte.
async test "utf8 name survives file round-trip" {
  let repo = @parse.parse_repository_from_file("tests/testdata/utf8-name.step") catch {
    @parse.StepParseError(info) =>
      fail("StepParseError: " + @parse.format_step_parse_error(info))
    _ => fail("unexpected error while parsing utf8-name.step")
  }
  let out = repo.to_step_file()
  assert_true(out.contains("café"))
  assert_eq(out, fid_reparse(out))
}

///|
// A complex instance whose parts cannot be typed must keep its original text,
// not become a bogus `__COMPLEX__(...)` simple entity.
test "lenient complex instance keeps its text" {
  let input = fid_wrap("#1=(FOO_BAR);")
  let out = match @parse.parse_repository_from_string_lenient_result(input) {
    @parse.ParseRepositoryResult::Ok(repo) => repo.to_step_file()
    @parse.ParseRepositoryResult::Err(info) =>
      fail("lenient parse failed: " + @parse.format_step_parse_error(info))
  }
  assert_false(out.contains("__COMPLEX__"))
  assert_true(out.contains("#1=(FOO_BAR);"))
  // The strict parser cannot type this instance, so check idempotence with
  // the lenient parser that produced it.
  let again = match @parse.parse_repository_from_string_lenient_result(out) {
    @parse.ParseRepositoryResult::Ok(repo) => repo.to_step_file()
    @parse.ParseRepositoryResult::Err(info) =>
      fail("lenient re-parse failed: " + @parse.format_step_parse_error(info))
  }
  assert_eq(out, again)
}

///|
// Malformed entity ids must be rejected rather than silently coerced.
test "malformed entity id is rejected" {
  let input = fid_wrap("#12abc=CARTESIAN_POINT('p',(1.,2.,3.));")
  match @parse.parse_repository_from_string_result(input) {
    @parse.ParseRepositoryResult::Err(_) => ()
    @parse.ParseRepositoryResult::Ok(_) =>
      fail("malformed entity id '#12abc' was accepted")
  }
}
