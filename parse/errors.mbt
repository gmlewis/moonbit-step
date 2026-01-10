///|
// Parse errors for STEP/ISO-10303-21.
//
// We use MoonBit's built-in error mechanism (`raise`) so parsing failures are
// reportable and catchable.

///|
///\
// Structured info for a parse error.
//
// `line`/`col` are 1-based when present.
pub struct StepParseErrorInfo {
  message : String
  line : Int?
  col : Int?
  stmt : String?
}

///|
pub suberror StepParseError {
  StepParseError(StepParseErrorInfo)
}

///|
// Raise a generic parse error.
pub fn[T] fail_parse() -> T raise StepParseError {
  raise StepParseError({
    message: "parse error",
    line: None,
    col: None,
    stmt: None,
  })
}

///|
// Raise a parse error with a message.
pub fn[T] fail_parse_msg(msg : String) -> T raise StepParseError {
  raise StepParseError({ message: msg, line: None, col: None, stmt: None })
}

///|
// Raise a parse error with statement context.
pub fn[T] fail_parse_stmt(
  msg : String,
  stmt : String,
) -> T raise StepParseError {
  raise StepParseError({ message: msg, line: None, col: None, stmt: Some(stmt) })
}

///|
// Raise a parse error with position + statement context.
pub fn[T] fail_parse_at(
  msg : String,
  line : Int,
  col : Int,
  stmt : String,
) -> T raise StepParseError {
  raise StepParseError({
    message: msg,
    line: Some(line),
    col: Some(col),
    stmt: Some(stmt),
  })
}

///|
// Convert structured parse error info to a human-friendly one-liner.
pub fn format_step_parse_error(info : StepParseErrorInfo) -> String {
  let pos_prefix = match (info.line, info.col) {
    (Some(l), Some(c)) =>
      "@" + Int::to_string(l) + ":" + Int::to_string(c) + ": "
    _ => ""
  }
  let header = pos_prefix + info.message
  let stmt_preview = match info.stmt {
    None => ""
    Some(s) => {
      // Keep error output bounded; show a short preview.
      let max_len = 240
      let preview = if s.length() > max_len {
        String::unsafe_substring(s, start=0, end=max_len) + "…"
      } else {
        s
      }
      "\nStatement:\n  " + preview.replace(old="\n", new="\n  ")
    }
  }
  let caret_block = match info.stmt {
    None => ""
    Some(s) => {
      let first_line = match String::find(s, "\n") {
        None => s
        Some(i) => String::unsafe_substring(s, start=0, end=i)
      }
      match caret_col_in_stmt(info.message, first_line) {
        None => ""
        Some(col1) => "\n" + render_caret_line(col1)
      }
    }
  }
  let hint = step_parse_hint(info)
  let hint_block = match hint {
    None => ""
    Some(h) => "\nHint: " + h
  }
  header + stmt_preview + caret_block + hint_block
}

///|
fn cu_at_err(s : String, i : Int) -> Int {
  UInt16::to_int(String::code_unit_at(s, i))
}

///|
fn render_spaces(n : Int) -> String {
  let builder = StringBuilder::new()
  for _ in 0..<n {
    builder.write_char(' ')
  }
  builder.to_string()
}

///|
// Render a caret line aligned with the statement shown under "Statement:".
// `col1` is 1-based column in the statement.
fn render_caret_line(col1 : Int) -> String {
  let col0 = if col1 <= 1 { 0 } else { col1 - 1 }
  // Statement lines are prefixed with two spaces in format_step_parse_error.
  "  " + render_spaces(col0) + "^"
}

///|
// Heuristically choose a useful caret position inside the statement.
// This is intentionally conservative: only return a caret position when we're
// reasonably sure where the user should look.
fn caret_col_in_stmt(msg : String, stmt_first_line : String) -> Int? {
  if stmt_first_line.length() == 0 {
    return None
  }

  // Most common newbie mistake: missing '=' between id and entity name.
  if msg.contains("missing '='") {
    if cu_at_err(stmt_first_line, 0) == Char::to_int('#') {
      let mut digits = 0
      let n = stmt_first_line.length()
      let mut i = 1
      while i < n {
        let ci = cu_at_err(stmt_first_line, i)
        if ci >= Char::to_int('0') && ci <= Char::to_int('9') {
          digits = digits + 1
          i = i + 1
          continue
        }
        break
      }
      if digits > 0 {
        // '=' should appear after "#" + digits.
        return Some(2 + digits)
      }
    }
    return Some(1)
  }
  if msg.contains("invalid entity id") {
    return Some(1)
  }
  if msg.contains("missing '('") {
    match String::find(stmt_first_line, "=") {
      None => return None
      Some(eq0) => {
        let n = stmt_first_line.length()
        let mut i = eq0 + 1
        // skip spaces
        while i < n {
          let ci = cu_at_err(stmt_first_line, i)
          if ci == Char::to_int(' ') || ci == Char::to_int('\t') {
            i = i + 1
            continue
          }
          break
        }
        // scan name token
        while i < n {
          let ci = cu_at_err(stmt_first_line, i)
          let is_upper = ci >= Char::to_int('A') && ci <= Char::to_int('Z')
          let is_digit = ci >= Char::to_int('0') && ci <= Char::to_int('9')
          let is_us = ci == Char::to_int('_')
          if is_upper || is_digit || is_us {
            i = i + 1
            continue
          }
          break
        }
        // caret points where '(' should be (1-based)
        return Some(i + 1)
      }
    }
  }
  if msg.contains("unterminated") && msg.contains("string") {
    match String::find(stmt_first_line, "'") {
      Some(i) => return Some(i + 1)
      None => return Some(1)
    }
  }
  if msg.contains("unterminated") && msg.contains("comment") {
    match String::find(stmt_first_line, "/*") {
      Some(i) => return Some(i + 1)
      None => return Some(1)
    }
  }
  None
}

///|
// Provide a beginner-friendly hint when we can confidently infer intent.
fn step_parse_hint(info : StepParseErrorInfo) -> String? {
  let msg = info.message
  if msg.contains("missing '='") {
    return Some(
      "In the DATA section, each entity statement looks like `#123=ENTITY_NAME(...);`. " +
      "Make sure there is an '=' between the id and the entity name.",
    )
  }
  if msg.contains("invalid entity id") {
    return Some(
      "Entity ids start with '#' followed by digits, e.g. `#10=...;`. " +
      "If you see `#10FOO(...)`, you probably missed an '='.",
    )
  }
  if msg.contains("missing '('") {
    return Some(
      "After an entity name you should have an argument list in parentheses, e.g. `PLANE(...);` " +
      "or even `SOME_ENTITY();` if it has no arguments.",
    )
  }
  if msg.contains("unterminated") && msg.contains("string") {
    return Some(
      "STEP strings use single quotes, and a literal quote is written by doubling it: `It''s fine`. " +
      "Make sure the string has a closing `'`.",
    )
  }
  if msg.contains("unterminated") && msg.contains("comment") {
    return Some(
      "Block comments must be closed with `*/`. If you intended the characters `/*` inside a string, " +
      "wrap them in single quotes.",
    )
  }
  None
}
