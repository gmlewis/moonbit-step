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

///|
pub fn fmt_snapped(n : Double) -> String {
  let eps = 1.e-5
  let sign_str = if n < -eps / 2.0 { "-" } else { "" }
  let abs_v = n.abs()
  let scaled = (abs_v / eps + 0.5).to_int()
  let whole = scaled / 100000
  let frac = scaled % 100000
  let mut frac_str = frac.to_string()
  while frac_str.length() < 5 {
    frac_str = "0" + frac_str
  }
  "\{sign_str}\{whole}.\{frac_str}"
}
