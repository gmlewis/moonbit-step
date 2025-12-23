///|
// A real-world stress test (not AP242, but exercises comments/newlines/large files).
// We assert idempotence of parse->serialize->parse->serialize.

async test "machine_contact_medium_roundtrip_is_idempotent" {
  let repo1 = @parse.parse_repository_from_file(
    "tests/testdata/MachineContactMedium.step",
  )
  let out1 = repo1.to_step_file()
  let repo2 = @parse.parse_repository_from_string(out1)
  let out2 = repo2.to_step_file()
  if out1 != out2 {
    // Find first differing line to help diagnose non-idempotence.
    let mut line_no = 1
    let mut i = 0
    let n1 = out1.length()
    let n2 = out2.length()
    let n = if n1 < n2 { n1 } else { n2 }
    while i < n {
      if UInt16::to_int(String::code_unit_at(out1, i)) !=
        UInt16::to_int(String::code_unit_at(out2, i)) {
        break
      }
      if UInt16::to_int(String::code_unit_at(out1, i)) == Char::to_int('\n') {
        line_no = line_no + 1
      }
      i = i + 1
    }
    fn substr(s : String, start : Int, end : Int) -> String {
      String::unsafe_substring(s, start~, end~)
    }

    fn get_line(s : String, target_line : Int) -> String {
      let mut line = 1
      let mut start = 0
      for j in 0..<s.length() {
        if UInt16::to_int(String::code_unit_at(s, j)) == Char::to_int('\n') {
          if line == target_line {
            return substr(s, start, j)
          }
          line = line + 1
          start = j + 1
        }
      }
      if line == target_line {
        return substr(s, start, s.length())
      }
      ""
    }

    let l1 = get_line(out1, line_no)
    let l2 = get_line(out2, line_no)
    let cu1 = if i < n1 {
      UInt16::to_int(String::code_unit_at(out1, i))
    } else {
      -1
    }
    let cu2 = if i < n2 {
      UInt16::to_int(String::code_unit_at(out2, i))
    } else {
      -1
    }
    let ctx_start = if i > 40 { i - 40 } else { 0 }
    let ctx_end1 = if i + 40 < n1 { i + 40 } else { n1 }
    let ctx_end2 = if i + 40 < n2 { i + 40 } else { n2 }
    let ctx1 = substr(out1, ctx_start, ctx_end1)
    let ctx2 = substr(out2, ctx_start, ctx_end2)
    println("first differing index: \{i}")
    println("first differing line: \{line_no}")
    println("code_unit out1/out2 at index: \{cu1} / \{cu2}")
    println("out1 line: [\{l1}]")
    println("out2 line: [\{l2}]")
    println("out1 ctx: [\{ctx1}]")
    println("out2 ctx: [\{ctx2}]")
    assert_true(false)
  }

  // Sanity: should contain a known early entity id.
  assert_true(
    out2.contains("#10=MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION"),
  )
}
