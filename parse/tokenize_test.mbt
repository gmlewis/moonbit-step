///|
test "tokenize_complex_instance_row" {
  let data = "#187=(\nGEOMETRIC_REPRESENTATION_CONTEXT(3)\nREPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')\n);"
  let rows = tokenize_step_data_section(data)
  inspect(rows.length(), content="1")
  inspect(rows[0].id.value, content="187")
  inspect(rows[0].name, content="__COMPLEX__")
  // Args should preserve the leading '(' so downstream can roundtrip.
  inspect(rows[0].args.has_prefix("("), content="true")
  inspect(
    rows[0].args.has_prefix("(\nGEOMETRIC_REPRESENTATION_CONTEXT(3)"),
    content="true",
  )
}

///|
test "split_statements_contract_semicolons_in_strings" {
  let data = "#1=FOO('X;Y'); #2=BAR('Z');"
  let stmts = split_statements(data)
  inspect(stmts.length(), content="2")
  assert_true(stmts[0].contains("'X;Y'"))
  assert_true(stmts[1].contains("#2=BAR('Z')"))
}

///|
test "split_statements_with_pos_tracks_line_and_col" {
  let data = "\n  #1=FOO('A');\n#2=BAR('B');"
  let spans = split_statements_with_pos(data) catch {
    @parse.StepParseError(info) =>
      fail("unexpected parse error: " + format_step_parse_error(info))
  }
  inspect(spans.length(), content="2")
  inspect(spans[0].line, content="2")
  inspect(spans[0].col, content="3")
  inspect(spans[1].line, content="3")
  inspect(spans[1].col, content="1")
}

///|
test "tokenize_rows_carry_line_and_col" {
  let data = "\n  #1=FOO('A');\n#2=BAR('B');"
  let rows = tokenize_step_data_section(data)
  inspect(rows.length(), content="2")
  inspect(rows[0].line, content="2")
  inspect(rows[0].col, content="3")
  inspect(rows[1].line, content="3")
  inspect(rows[1].col, content="1")
}

///|
test "tokenize_errors_include_position_and_stmt" {
  let data = "#1=FOO('A');\n#2FOO('B');"
  let mut got_error = false
  try {
    let _ = tokenize_step_data_section(data)
  } catch {
    @parse.StepParseError(info) => {
      got_error = true
      match (info.line, info.col, info.stmt) {
        (Some(2), Some(1), Some(stmt)) =>
          assert_true(stmt.contains("#2FOO('B')"))
        _ => fail("missing expected (line,col,stmt) in StepParseErrorInfo")
      }
      let msg = format_step_parse_error(info)
      assert_true(msg.contains("@2:1"))
      assert_true(msg.contains("missing '='"))
      assert_true(msg.contains("\n    ^"))
    }
  }
  if !got_error {
    fail("expected tokenize failure")
  }
}

///|
test "split_statements_contract_doubled_quotes_in_strings" {
  // STEP string escaping uses doubled quotes: '' represents a literal '.
  // Semicolons inside strings must not terminate the statement.
  let data = "#1=FOO('a''b;c');#2=BAR('d');"
  let stmts = split_statements(data)
  inspect(stmts.length(), content="2")
  assert_true(stmts[0].contains("'a''b;c'"))
  assert_true(stmts[1].contains("#2=BAR('d')"))
}

///|
test "split_statements_contract_nested_parentheses" {
  let data = "#1=FOO((1,(2,3)),4);\n#2=BAR(5);"
  let stmts = split_statements(data)
  inspect(stmts.length(), content="2")
  assert_true(stmts[0].contains("FOO((1,(2,3)),4)"))
  assert_true(stmts[1].contains("BAR(5)"))
}

///|
test "split_statements_with_pos_reports_unterminated_string_at_quote" {
  // Avoid introducing any later quote that could accidentally terminate the
  // string and shift the reported location.
  let data = "#1=FOO('unterminated\n#2=BAR(1);"
  let mut got_error = false
  try {
    let _ = split_statements_with_pos(data)
  } catch {
    @parse.StepParseError(info) => {
      got_error = true
      assert_true(info.message.contains("unterminated"))
      assert_true(info.message.contains("string"))
      match (info.line, info.col) {
        // The opening quote in "#1=FOO('unterminated" is at column 8.
        (Some(1), Some(8)) => ()
        _ => fail("expected unterminated string at @1:8")
      }
      // Statement preview should include the start of the unterminated string.
      match info.stmt {
        Some(stmt) => assert_true(stmt.contains("#1=FOO('unterminated"))
        None => fail("expected stmt in StepParseErrorInfo")
      }
    }
  }
  if !got_error {
    fail("expected unterminated string failure")
  }
}
