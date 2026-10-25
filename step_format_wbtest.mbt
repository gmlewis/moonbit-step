///|
test "fmt_num emits STEP-conforming reals" {
  inspect(fmt_num(10.0), content="10.0")
  inspect(fmt_num(2.5), content="2.5")
  inspect(fmt_num(0.0), content="0.0")
  inspect(fmt_num(-0.0), content="0.0")
  // Trig residue is rounded away, so it cannot reach exponent form.
  inspect(fmt_num(1.0e-16), content="0.0")
  inspect(fmt_num(-4.1779407933722266e-15), content="0.0")
  // A genuine exponent must use an upper-case E and a decimal point.
  inspect(fmt_num(1.0e-9), content="1.0E-9")
  inspect(fmt_num(-1.25e-7), content="-1.25E-7")
}
