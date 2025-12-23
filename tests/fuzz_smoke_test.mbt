///|
// Lightweight, deterministic fuzz smoke tests.
//
// Goals:
// - Never abort / never hang on weird inputs.
// - If parsing succeeds, roundtrip is stable: parse -> to_step_file -> parse.
//
// These are intentionally time/size-bounded and deterministic (fixed seed),
// so they can run in CI without flakes.

fn pm_next(state : Int) -> Int {
  // Park-Miller RNG (minimal standard): state = (state * 48271) mod 2147483647
  // Requires state in 1..2147483646.
  let m = 2147483647
  let a = 48271
  let next = state * a % m
  if next == 0 {
    1
  } else {
    next
  }
}

///|
fn rand_range(state : Int, hi_exclusive : Int) -> (Int, Int) {
  let s2 = pm_next(state)
  if hi_exclusive <= 1 {
    (0, s2)
  } else {
    (s2 % hi_exclusive, s2)
  }
}

///|
fn rand_bool(state : Int, numerator : Int, denom : Int) -> (Bool, Int) {
  let (v, s2) = rand_range(state, denom)
  (v < numerator, s2)
}

///|
fn rand_upper_name(state : Int) -> (String, Int) {
  let mut s = state
  let (len0, s1) = rand_range(s, 10)
  s = s1
  let len = 3 + len0 // 3..12
  let builder = StringBuilder::new()
  for _ in 0..<len {
    let (choice, s2) = rand_range(s, 28)
    s = s2
    if choice < 26 {
      builder.write_char((Char::to_int('A') + choice).unsafe_to_char())
    } else {
      builder.write_char('_')
    }
  }
  (builder.to_string(), s)
}

///|
fn rand_digits(state : Int, min_len : Int, max_len : Int) -> (String, Int) {
  let mut s = state
  let span = if max_len <= min_len { 1 } else { max_len - min_len + 1 }
  let (d0, s1) = rand_range(s, span)
  s = s1
  let len = min_len + d0
  let builder = StringBuilder::new()
  for i in 0..<len {
    let (c, s2) = rand_range(s, 10)
    s = s2
    // avoid leading zero sometimes
    if i == 0 && len > 1 {
      let digit = if c == 0 { 1 } else { c }
      builder.write_char((Char::to_int('0') + digit).unsafe_to_char())
    } else {
      builder.write_char((Char::to_int('0') + c).unsafe_to_char())
    }
  }
  (builder.to_string(), s)
}

///|
fn rand_step_string(state : Int) -> (String, Int) {
  let mut s = state
  let (len0, s1) = rand_range(s, 30)
  s = s1
  let len = len0 // 0..29
  let builder = StringBuilder::new()
  builder.write_char('\'')
  for _ in 0..<len {
    let (choice, s2) = rand_range(s, 40)
    s = s2
    if choice < 26 {
      builder.write_char((Char::to_int('a') + choice).unsafe_to_char())
    } else if choice < 30 {
      builder.write_char(' ')
    } else if choice < 33 {
      // include delimiter-looking tokens inside strings
      if choice == 30 {
        builder.write_string("ENDSEC;")
      } else if choice == 31 {
        builder.write_string("DATA;")
      } else {
        builder.write_string("/*")
      }
    } else if choice == 33 {
      // escaped quote: doubled ''
      builder.write_char('\'')
      builder.write_char('\'')
    } else {
      builder.write_char('-')
    }
  }
  builder.write_char('\'')
  (builder.to_string(), s)
}

///|
fn rand_comment(state : Int) -> (String, Int) {
  let mut s = state
  let (len0, s1) = rand_range(s, 25)
  s = s1
  let len = 3 + len0
  let builder = StringBuilder::new()
  builder.write_string("/*")
  for _ in 0..<len {
    let (choice, s2) = rand_range(s, 20)
    s = s2
    if choice < 10 {
      builder.write_char((Char::to_int('A') + choice).unsafe_to_char())
    } else if choice < 13 {
      builder.write_char(' ')
    } else if choice == 13 {
      builder.write_string("ENDSEC;")
    } else if choice == 14 {
      builder.write_string("DATA;")
    } else if choice == 15 {
      builder.write_char(';')
    } else {
      builder.write_char('_')
    }
  }
  builder.write_string("*/")
  (builder.to_string(), s)
}

///|
fn rand_value(state : Int, depth : Int) -> (String, Int) {
  let mut s = state
  let (choice, s1) = rand_range(s, 8)
  s = s1
  if choice == 0 {
    ("$", s)
  } else if choice == 1 {
    let (d, s2) = rand_digits(s, 1, 6)
    (d, s2)
  } else if choice == 2 {
    // ref
    let (d, s2) = rand_digits(s, 1, 5)
    ("#" + d, s2)
  } else if choice == 3 {
    let (str, s2) = rand_step_string(s)
    (str, s2)
  } else if choice == 4 {
    // float-ish
    let (a, s2) = rand_digits(s, 1, 3)
    let (b, s3) = rand_digits(s2, 1, 3)
    (a + "." + b, s3)
  } else if choice == 5 && depth > 0 {
    // nested list
    let mut s2 = s
    let (count0, s3) = rand_range(s2, 4)
    s2 = s3
    let count = 1 + count0
    let builder = StringBuilder::new()
    builder.write_char('(')
    for i in 0..<count {
      let (v, s4) = rand_value(s2, depth - 1)
      s2 = s4
      if i > 0 {
        builder.write_char(',')
      }
      builder.write_string(v)
    }
    builder.write_char(')')
    (builder.to_string(), s2)
  } else if choice == 6 {
    // boolean-ish
    let (b, s2) = rand_bool(s, 1, 2)
    (if b { ".T." } else { ".F." }, s2)
  } else {
    // enum-ish
    let (name, s2) = rand_upper_name(s)
    ("." + name + ".", s2)
  }
}

///|
fn rand_args(state : Int) -> (String, Int) {
  let mut s = state
  let (count0, s1) = rand_range(s, 6)
  s = s1
  let count = count0
  let builder = StringBuilder::new()
  builder.write_char('(')
  for i in 0..<count {
    let (v, s2) = rand_value(s, 2)
    s = s2
    if i > 0 {
      builder.write_char(',')
    }
    builder.write_string(v)
    // sometimes inject a comment after a value
    let (want_comment, s3) = rand_bool(s, 1, 6)
    s = s3
    if want_comment {
      let (c, s4) = rand_comment(s)
      s = s4
      builder.write_string(c)
    }
  }
  builder.write_char(')')
  (builder.to_string(), s)
}

///|
fn rand_data_statement(state : Int, id : Int) -> (String, Int) {
  let mut s = state
  let (name, s1) = rand_upper_name(s)
  s = s1
  let (args, s2) = rand_args(s)
  s = s2
  let stmt = "#" + Int::to_string(id) + "=" + name + args + ";"
  (stmt, s)
}

///|
fn wrap_as_step_file(data_section : String) -> String {
  // Keep header minimal but valid.
  "ISO-10303-21;\n" +
  "HEADER;\n" +
  "FILE_DESCRIPTION(('fuzz'),'2;1');\n" +
  "ENDSEC;\n" +
  "DATA;\n" +
  data_section +
  "\nENDSEC;\n" +
  "END-ISO-10303-21;\n"
}

///|
test "fuzz_parse_never_aborts_and_roundtrips_when_ok" {
  let mut state = 1234567
  // Bound runtime: small corpus, small statements.
  for iter in 0..<120 {
    let (stmt_count0, s1) = rand_range(state, 25)
    state = s1
    let stmt_count = 1 + stmt_count0
    let builder = StringBuilder::new()
    for i in 0..<stmt_count {
      let (stmt, s2) = rand_data_statement(state, 1 + i)
      state = s2
      builder.write_string(stmt)
      builder.write_char('\n')
    }
    let content = wrap_as_step_file(builder.to_string())
    match @parse.parse_repository_from_string_result(content) {
      @parse.ParseRepositoryResult::Err(_info) =>
        // Accept parse errors; invariant is: never abort/hang.
        ()
      @parse.ParseRepositoryResult::Ok(repo1) => {
        let out1 = repo1.to_step_file()
        match @parse.parse_repository_from_string_result(out1) {
          @parse.ParseRepositoryResult::Err(info2) =>
            fail(
              "fuzz: roundtrip re-parse failed: " +
              @parse.format_step_parse_error(info2),
            )
          @parse.ParseRepositoryResult::Ok(repo2) => {
            let out2 = repo2.to_step_file()
            assert_eq(out1, out2)
          }
        }
      }
    }
  }
}

///|
test "fuzz_tokenizer_never_aborts" {
  let mut state = 7654321
  for _iter in 0..<200 {
    let (stmt_count0, s1) = rand_range(state, 18)
    state = s1
    let stmt_count = stmt_count0
    let builder = StringBuilder::new()
    for i in 0..<stmt_count {
      let (stmt, s2) = rand_data_statement(state, 100 + i)
      state = s2
      builder.write_string(stmt)
      // sprinkle some extra whitespace
      let (spaces0, s3) = rand_range(state, 3)
      state = s3
      for _ in 0..<spaces0 {
        builder.write_char(' ')
      }
    }
    try {
      let _ = @parse.tokenize_step_data_section(builder.to_string())

    } catch {
      @parse.StepParseError(_info) =>
        // expected sometimes
        ()
    }
  }
}
