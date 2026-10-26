///|
async test "load_font reports a missing font" {
  let msg = try {
    let _ = @cad.load_font("__missing_font_for_test__")
    fail("expected load_font to raise LoaderError")
  } catch {
    @cad.LoaderError(msg) => msg
    e => fail("unexpected error: \{e}")
  }
  inspect(
    msg,
    content="Font '__missing_font_for_test__' not found. See above for instructions.",
  )
}
