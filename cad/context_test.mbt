///|
test "snap_double" {
  // Exact values with 1.e-5 snapping
  let snapping = Some(1.e-5)
  inspect(snap_double(3.0, snapping), content="3.0000000000000004")
  inspect(snap_double(0.0, snapping), content="0")
  inspect(snap_double(-3.0, snapping), content="-3.0000000000000004")

  // Values near snap points
  inspect(snap_double(2.88333, snapping), content="2.8833300000000004")
  inspect(snap_double(2.883330001, snapping), content="2.8833300000000004")
  inspect(snap_double(2.883329999, snapping), content="2.8833300000000004")

  // 1-micron snapping (1.e-3)
  let snapping = Some(1.e-3)
  inspect(snap_double(2.88333, snapping), content="2.883")
  inspect(snap_double(2.8839, snapping), content="2.884")

  // No snapping
  inspect(snap_double(2.88333, None), content="2.88333")
}

///|
test "fmt_double" {
  // 1.e-5 snapping
  let snapping = Some(1.e-5)
  inspect(fmt_double(3.0, snapping), content="3.00000")
  inspect(fmt_double(0.0, snapping), content="0.00000")
  inspect(fmt_double(-3.0, snapping), content="-3.00000")
  inspect(fmt_double(2.88333, snapping), content="2.88333")
  inspect(fmt_double(2.9, snapping), content="2.90000")

  // 1-micron snapping
  let snapping = Some(1.e-3)
  inspect(fmt_double(2.88333, snapping), content="2.883")
  inspect(fmt_double(2.9, snapping), content="2.900")

  // No snapping
  inspect(fmt_double(2.88333, None), content="2.88333")
}
