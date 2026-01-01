///|
test "snap_double" {
  // Exact values
  inspect(snap_double(3.0), content="3.0000000000000004")
  inspect(snap_double(0.0), content="0")
  inspect(snap_double(-3.0), content="-3.0000000000000004")

  // Values near snap points
  inspect(snap_double(2.88333), content="2.8833300000000004")
  inspect(snap_double(2.883330001), content="2.8833300000000004")
  inspect(snap_double(2.883329999), content="2.8833300000000004")

  // Value that was reported to shift
  // 2.88333 should NOT snap to 2.9
  assert_eq(snap_double(2.88333), 2.8833300000000004)
}

///|
test "fmt_double" {
  inspect(fmt_double(3.0), content="3.00000")
  inspect(fmt_double(0.0), content="0.00000")
  inspect(fmt_double(-3.0), content="-3.00000")
  inspect(fmt_double(2.88333), content="2.88333")
  inspect(fmt_double(2.9), content="2.90000")
  inspect(fmt_double(0.00001), content="0.00001")
  inspect(fmt_double(0.000001), content="0.00000")
}
