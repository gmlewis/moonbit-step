///|
// Benchmarks (run via `moon bench`).
//
// These are *not* part of `moon test`/`./test-all.sh`; they are intended as
// manual performance guardrails during development.

///|
// fn tokenize_len(data_section : String) -> Int {
//   @parse.tokenize_step_data_section(data_section).length() catch {
//     @parse.StepParseError(_) => 0
//   }
// }

// ///|
// fn parse_repo_len(content : String) -> Int {
//   match @parse.parse_repository_from_string_result(content) {
//     @parse.ParseRepositoryResult::Ok(repo) => repo.len()
//     @parse.ParseRepositoryResult::Err(_) => 0
//   }
// }

// ///|
// fn parse_repo_or_fail(content : String) -> @repository.Repository raise Error {
//   match @parse.parse_repository_from_string_result(content) {
//     @parse.ParseRepositoryResult::Ok(repo) => repo
//     @parse.ParseRepositoryResult::Err(info) =>
//       fail(
//         "benchmark fixture parse failed: " +
//         @parse.format_step_parse_error(info),
//       )
//   }
// }

// ///|
// async fn load_normalized_strings(
//   fixture_path : StringView,
// ) -> (String, String) raise Error {
//   let repo = @parse.parse_repository_from_file(fixture_path) catch {
//     @parse.StepParseError(info) =>
//       fail(
//         "benchmark fixture parse failed: " +
//         @parse.format_step_parse_error(info),
//       )
//     _ => fail("benchmark fixture parse failed: unexpected error")
//   }
//   let full_file = repo.to_step_file()
//   let data_only = repo.to_step_data_section()
//   (full_file, data_only)
// }

///|
// Tokenization-only: DATA section -> RawEntityRows

// test (b : @bench.T) {
//   let (_full, data_section) = load_normalized_strings(
//     "tests/testdata/simple-box.step",
//   )
//   b.bench(name="tokenize/simple-box", fn() {
//     b.keep(tokenize_len(data_section))
//   })
// }

///|
// Parse-only: full file -> Repository

// test (b : @bench.T) {
//   let (content, _data) = load_normalized_strings(
//     b"tests/testdata/simple-box.step",
//   )
//   b.bench(name="parse/simple-box", fn() { b.keep(parse_repo_len(content)) })
// }

///|
// Serialize-only: Repository -> STEP file string

// test (b : @bench.T) {
//   let (content, _data) = load_normalized_strings(
//     b"tests/testdata/simple-box.step",
//   )
//   let repo = parse_repo_or_fail(content)
//   b.bench(name="to_step_file/simple-box", fn() {
//     let out = repo.to_step_file()
//     b.keep(out.length())
//   })
// }

///|
// Stress fixture variants

// test (b : @bench.T) {
//   let (_full, data_section) = load_normalized_strings(
//     b"tests/testdata/ap242-stress.step",
//   )
//   b.bench(name="tokenize/ap242-stress", fn() {
//     b.keep(tokenize_len(data_section))
//   })
// }

///|
// test (b : @bench.T) {
//   let (content, _data) = load_normalized_strings(
//     b"tests/testdata/ap242-stress.step",
//   )
//   b.bench(name="parse/ap242-stress", fn() { b.keep(parse_repo_len(content)) })
// }

///|
// test (b : @bench.T) {
//   let (content, _data) = load_normalized_strings(
//     b"tests/testdata/ap242-stress.step",
//   )
//   let repo = parse_repo_or_fail(content)
//   b.bench(name="to_step_file/ap242-stress", fn() {
//     let out = repo.to_step_file()
//     b.keep(out.length())
//   })
// }
