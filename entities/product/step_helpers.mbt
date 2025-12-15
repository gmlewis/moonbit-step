///|
fn step_str_or_dollar(s : String) -> String {
  if s == "$" {
    "$"
  } else {
    @step.step_str(s)
  }
}
