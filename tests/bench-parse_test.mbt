///|
// Benchmarks (run via `moon bench`).
//
// These are manual performance guardrails, kept out of the normal
// `moon test` / `./test-all.sh` loop. Run with:
//   moon bench --release --target native tests/
//
// The corpus is generated in-process rather than read from the tracked
// `tests/testdata/*.step` files: `moon bench` does not support async
// benchmarks, and the MoonBit file-I/O API is async-only. Generating the
// STEP text keeps the benchmarks synchronous and self-contained.

///|
fn bench_fixture(entity_count : Int32) -> (String, String) {
  let body = StringBuilder()
  for i in 1..<=entity_count {
    body.write_string("#\{i}=CARTESIAN_POINT('p\{i}',(\{i}.0,0.0,0.0));\n")
  }
  let data = body.to_string()
  let full = "ISO-10303-21;\n" +
    "HEADER;\n" +
    "FILE_DESCRIPTION(('bench'),'2;1');\n" +
    "FILE_NAME('bench.step','2025-01-01T00:00:00',('gmlewis/step'),('gmlewis/step'),'moon','moonbit','none');\n" +
    "FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));\n" +
    "ENDSEC;\n" +
    "DATA;\n" +
    data +
    "ENDSEC;\n" +
    "END-ISO-10303-21;\n"
  (full, data)
}

///|
fn tokenize_len(data_section : String) -> Int32 {
  try @parse.tokenize_step_data_section(data_section).length() catch {
    _ => 0
  } noraise {
    n => n
  }
}

///|
fn parse_repo_len(content : String) -> Int32 {
  match @parse.parse_repository_from_string_result(content) {
    @parse.ParseRepositoryResult::Ok(repo) => repo.len()
    @parse.ParseRepositoryResult::Err(_) => 0
  }
}

///|
test "bench tokenize/200" (b : @bench.T) {
  let (_full, data) = bench_fixture(200)
  b.bench(fn() { b.keep(tokenize_len(data)) })
}

///|
test "bench parse/200" (b : @bench.T) {
  let (full, _data) = bench_fixture(200)
  b.bench(fn() { b.keep(parse_repo_len(full)) })
}

///|
test "bench to_step_file/200" (b : @bench.T) {
  let (full, _data) = bench_fixture(200)
  let repo = match @parse.parse_repository_from_string_result(full) {
    @parse.ParseRepositoryResult::Ok(r) => r
    @parse.ParseRepositoryResult::Err(_) =>
      fail("benchmark fixture parse failed")
  }
  b.bench(fn() { b.keep(repo.to_step_file().length()) })
}

///|
test "bench tokenize/2000" (b : @bench.T) {
  let (_full, data) = bench_fixture(2000)
  b.bench(fn() { b.keep(tokenize_len(data)) })
}

///|
test "bench parse/2000" (b : @bench.T) {
  let (full, _data) = bench_fixture(2000)
  b.bench(fn() { b.keep(parse_repo_len(full)) })
}

///|
test "bench to_step_file/2000" (b : @bench.T) {
  let (full, _data) = bench_fixture(2000)
  let repo = match @parse.parse_repository_from_string_result(full) {
    @parse.ParseRepositoryResult::Ok(r) => r
    @parse.ParseRepositoryResult::Err(_) =>
      fail("benchmark fixture parse failed")
  }
  b.bench(fn() { b.keep(repo.to_step_file().length()) })
}
