///|
// STEP text helpers
pub fn step_str(s : String) -> String {
  let replaced = s.replace(old="'", new="''")
  "'\{replaced}'"
}

///|
pub fn fmt_num(n : Double) -> String {
  // ISO 10303-21 reals are [sign] digits "." digits [ "E" [sign] digits ]:
  // the decimal point is mandatory and the exponent marker must be an
  // upper-case E. Rounding trig residue (< 1e-12) to zero keeps such values
  // out of exponent form (and makes nominally axis-aligned geometry exact).
  if n.abs() < 1.0e-12 {
    return "0.0"
  }
  if n == n.floor() {
    "\{n.to_int()}.0"
  } else {
    let s = n.to_string().replace(old="e", new="E")
    let parts = s.split("E").collect()
    if parts.length() == 2 {
      let mant = parts[0].to_owned()
      let mant = if mant.contains(".") { mant } else { mant + ".0" }
      mant + "E" + parts[1].to_owned()
    } else {
      s
    }
  }
}
