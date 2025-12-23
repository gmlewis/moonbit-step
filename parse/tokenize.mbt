///|
pub struct RawEntityRow {
  id : @step.EntityId
  name : String
  args : String
  line : Int
  col : Int
}

///|
pub struct StatementSpan {
  stmt : String
  line : Int
  col : Int
}

///|
// Remove STEP block comments (/* ... */), preserving newlines.
//
// Comments are removed only when they occur outside of STEP string literals.
// We insert a single space where the comment started to avoid accidentally
// merging adjacent tokens.
fn strip_step_comments(input : String) -> String raise StepParseError {
  let builder = StringBuilder::new()
  let n = input.length()
  let mut in_str = false
  let mut in_comment = false
  let mut line = 1
  let mut col = 1
  let mut comment_line = 1
  let mut comment_col = 1
  let mut i = 0
  while i < n {
    let ci = cu_at(input, i)
    if in_comment {
      if ci == Char::to_int('*') &&
        i + 1 < n &&
        cu_at(input, i + 1) == Char::to_int('/') {
        in_comment = false
        i = i + 2
        col = col + 2
        continue
      }
      if ci == Char::to_int('\n') {
        builder.write_char('\n')
        line = line + 1
        col = 1
        i = i + 1
        continue
      }
      col = col + 1
      i = i + 1
      continue
    }
    if in_str {
      if ci == Char::to_int('\'') {
        if i + 1 < n && cu_at(input, i + 1) == Char::to_int('\'') {
          // STEP string escaping: doubled quotes '' represent a literal '.
          builder.write_char('\'')
          builder.write_char('\'')
          i = i + 2
          col = col + 2
          continue
        } else {
          in_str = false
          builder.write_char('\'')
          i = i + 1
          col = col + 1
          continue
        }
      }
      builder.write_char(ci.unsafe_to_char())
      i = i + 1
      if ci == Char::to_int('\n') {
        line = line + 1
        col = 1
      } else {
        col = col + 1
      }
      continue
    }

    // Outside strings.
    if ci == Char::to_int('\'') {
      in_str = true
      builder.write_char('\'')
      i = i + 1
      col = col + 1
      continue
    }
    if ci == Char::to_int('/') &&
      i + 1 < n &&
      cu_at(input, i + 1) == Char::to_int('*') {
      // Start comment.
      builder.write_char(' ')
      in_comment = true
      comment_line = line
      comment_col = col
      i = i + 2
      col = col + 2
      continue
    }
    builder.write_char(ci.unsafe_to_char())
    i = i + 1
    if ci == Char::to_int('\n') {
      line = line + 1
      col = 1
    } else {
      col = col + 1
    }
  }
  if in_comment {
    fail_parse_at(
      "unterminated STEP block comment (missing '*/')", comment_line, comment_col,
      "/*",
    )
  }
  builder.to_string()
}

///|
fn substr(s : String, start : Int, end : Int) -> String {
  String::unsafe_substring(s, start~, end~)
}

///|
fn cu_at(s : String, i : Int) -> Int {
  UInt16::to_int(String::code_unit_at(s, i))
}

///|
fn parse_int_dec(s : String) -> Int {
  let t = s.trim().to_string()
  let mut sign = 1
  let start_i = if t.length() > 0 && cu_at(t, 0) == Char::to_int('-') {
    sign = -1
    1
  } else {
    0
  }
  let mut acc = 0
  for i in start_i..<t.length() {
    let ci = cu_at(t, i)
    if ci >= Char::to_int('0') && ci <= Char::to_int('9') {
      acc = acc * 10 + (ci - Char::to_int('0'))
    }
  }
  acc * sign
}

///|
// Split the DATA section into individual entity statements.
//
// This is a minimal tokenizer that:
// - splits on `;` only when not inside parentheses and not inside `'...'`.
// - ignores empty statements.
pub fn split_statements(data_section : String) -> Array[String] {
  let out : Array[String] = []
  let mut in_str = false
  let mut builder = StringBuilder::new()
  let n = data_section.length()
  let mut i = 0
  while i < n {
    let ci = cu_at(data_section, i)
    if ci == Char::to_int('\'') {
      if in_str {
        // STEP string escaping: doubled quotes '' represent a literal '.
        if i + 1 < n && cu_at(data_section, i + 1) == Char::to_int('\'') {
          builder.write_char('\'')
          builder.write_char('\'')
          i = i + 2
          continue
        }
        in_str = false
        builder.write_char('\'')
        i = i + 1
        continue
      }
      in_str = true
      builder.write_char('\'')
      i = i + 1
      continue
    }
    if !in_str && ci == Char::to_int(';') {
      let stmt = builder.to_string().trim().to_string()
      if stmt.length() > 0 {
        out.push(stmt)
      }
      builder = StringBuilder::new()
      i = i + 1
      continue
    }
    builder.write_char(ci.unsafe_to_char())
    i = i + 1
  }

  // trailing (if no ending ';')
  let trailing = builder.to_string().trim().to_string()
  if trailing.length() > 0 {
    out.push(trailing)
  }
  out
}

///|
// Like split_statements, but also returns a best-effort (line,col) for where each
// statement begins (1-based). Intended for better error messages.
pub fn split_statements_with_pos(
  data_section : String,
) -> Array[StatementSpan] raise StepParseError {
  let out : Array[StatementSpan] = []
  let mut in_str = false
  let mut builder = StringBuilder::new()
  let mut line = 1
  let mut col = 1
  let mut stmt_line = 1
  let mut stmt_col = 1
  let mut str_line = 1
  let mut str_col = 1
  let mut seen_non_ws = false
  let n = data_section.length()
  let mut i = 0
  while i < n {
    let ci = cu_at(data_section, i)

    // Skip leading whitespace outside strings.
    if !in_str && !seen_non_ws {
      if ci == Char::to_int(' ') ||
        ci == Char::to_int('\t') ||
        ci == Char::to_int('\n') ||
        ci == Char::to_int('\r') {
        if ci == Char::to_int('\n') {
          line = line + 1
          col = 1
        } else {
          col = col + 1
        }
        i = i + 1
        continue
      }
      // First non-whitespace character starts a statement.
      seen_non_ws = true
      stmt_line = line
      stmt_col = col
    }
    if ci == Char::to_int('\'') {
      if in_str {
        if i + 1 < n && cu_at(data_section, i + 1) == Char::to_int('\'') {
          builder.write_char('\'')
          builder.write_char('\'')
          i = i + 2
          col = col + 2
          continue
        }
        in_str = false
        builder.write_char('\'')
        i = i + 1
        col = col + 1
        continue
      }
      in_str = true
      str_line = line
      str_col = col
      builder.write_char('\'')
      i = i + 1
      col = col + 1
      continue
    }
    if !in_str && ci == Char::to_int(';') {
      let stmt = builder.to_string().trim().to_string()
      if stmt.length() > 0 {
        out.push(StatementSpan::{ stmt, line: stmt_line, col: stmt_col })
      }
      builder = StringBuilder::new()
      seen_non_ws = false
      i = i + 1
      col = col + 1
      continue
    }
    builder.write_char(ci.unsafe_to_char())
    if ci == Char::to_int('\n') {
      line = line + 1
      col = 1
    } else {
      col = col + 1
    }
    i = i + 1
  }
  let trailing = builder.to_string().trim().to_string()
  if trailing.length() > 0 {
    out.push(StatementSpan::{ stmt: trailing, line: stmt_line, col: stmt_col })
  }
  if in_str {
    fail_parse_at(
      "unterminated STEP string literal (missing closing '\'')",
      str_line,
      str_col,
      builder.to_string(),
    )
  }
  out
}

///|
fn apply_base(
  line : Int,
  col : Int,
  base_line : Int,
  base_col : Int,
) -> (Int, Int) {
  if line == 1 {
    (base_line, base_col + col - 1)
  } else {
    (base_line + line - 1, col)
  }
}

///|
fn parse_row(span : StatementSpan) -> RawEntityRow raise StepParseError {
  let stmt = span.stmt
  // Expected form: #<id>=<NAME>(<args>)
  let eq_idx = match String::find(stmt, "=") {
    Some(i) => i
    None =>
      fail_parse_at(
        "invalid DATA statement (missing '=')",
        span.line,
        span.col,
        stmt,
      )
  }
  let id_part = substr(stmt, 0, eq_idx).trim().to_string()
  if id_part.length() < 2 || cu_at(id_part, 0) != Char::to_int('#') {
    fail_parse_at(
      "invalid entity id (expected '#<int>')",
      span.line,
      span.col,
      stmt,
    )
  }
  let id_digits = substr(id_part, 1, id_part.length())
  let id_val = parse_int_dec(id_digits)
  let id = @step.EntityId::{ value: id_val }
  let rhs = substr(stmt, eq_idx + 1, stmt.length()).trim().to_string()

  // Complex entity instance form: #<id>=( <ENTITY1> ... <ENTITYN> );
  // This has no leading NAME before the opening paren.
  if rhs.length() > 0 && cu_at(rhs, 0) == Char::to_int('(') {
    return RawEntityRow::{
      id,
      name: "__COMPLEX__",
      args: rhs,
      line: span.line,
      col: span.col,
    }
  }
  let lp_idx = match String::find(rhs, "(") {
    Some(i) => i
    None =>
      fail_parse_at(
        "invalid DATA statement (missing '(')",
        span.line,
        span.col,
        stmt,
      )
  }
  let name = substr(rhs, 0, lp_idx).trim().to_string()
  let args = substr(rhs, lp_idx, rhs.length()).trim().to_string()
  RawEntityRow::{ id, name, args, line: span.line, col: span.col }
}

///|
pub fn tokenize_step_data_section(
  data_section : String,
) -> Array[RawEntityRow] raise StepParseError {
  tokenize_step_data_section_with_base(data_section, 1, 1)
}

///|
// Tokenize the DATA section but report positions relative to the full file.
// `base_line`/`base_col` are the 1-based position of the first character in
// `data_section` within the full (comment-stripped) file.
pub fn tokenize_step_data_section_with_base(
  data_section : String,
  base_line : Int,
  base_col : Int,
) -> Array[RawEntityRow] raise StepParseError {
  let stmts = split_statements_with_pos(data_section) catch {
    StepParseError(info) => {
      let (l, c) = match (info.line, info.col) {
        (Some(il), Some(ic)) => apply_base(il, ic, base_line, base_col)
        _ => (base_line, base_col)
      }
      raise StepParseError({
        message: info.message,
        line: Some(l),
        col: Some(c),
        stmt: info.stmt,
      })
    }
  }
  let rows = stmts.map(fn(span) {
    let (abs_line, abs_col) = apply_base(
      span.line,
      span.col,
      base_line,
      base_col,
    )
    parse_row(StatementSpan::{ stmt: span.stmt, line: abs_line, col: abs_col })
  })
  rows
}

///|
// Split a comma-separated arg list, respecting parentheses and strings.
// Input may include surrounding parentheses.
pub fn split_args(args : String) -> Array[String] {
  let s = args.trim().to_string()
  let mut inner_start = 0
  let mut inner_end = s.length()
  if inner_end >= 2 &&
    cu_at(s, 0) == Char::to_int('(') &&
    cu_at(s, inner_end - 1) == Char::to_int(')') {
    inner_start = 1
    inner_end = inner_end - 1
  }
  let out : Array[String] = []
  let mut depth = 0
  let mut in_str = false
  let mut skip_quote = false
  let mut start = inner_start
  for i in inner_start..<inner_end {
    let ci = cu_at(s, i)
    if ci == Char::to_int('\'') {
      if skip_quote {
        skip_quote = false
      } else if in_str {
        if i + 1 < inner_end && cu_at(s, i + 1) == Char::to_int('\'') {
          skip_quote = true
        } else {
          in_str = false
        }
      } else {
        in_str = true
      }
    } else if !in_str {
      if ci == Char::to_int('(') {
        depth = depth + 1
      } else if ci == Char::to_int(')') {
        if depth > 0 {
          depth = depth - 1
        }
      } else if ci == Char::to_int(',') && depth == 0 {
        let part = substr(s, start, i).trim().to_string()
        out.push(part)
        start = i + 1
      }
    }
  }
  if start <= inner_end {
    let part = substr(s, start, inner_end).trim().to_string()
    if part.length() > 0 {
      out.push(part)
    }
  }
  out
}
