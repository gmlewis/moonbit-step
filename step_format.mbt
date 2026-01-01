///|
// STEP text helpers
pub fn step_str(s : String) -> String {
  let replaced = s.replace(old="'", new="''")
  "'\{replaced}'"
}

///|
pub fn fmt_num(n : Double) -> String {
  if n == n.floor() {
    "\{n.to_int()}.0"
  } else {
    n.to_string()
  }
}
