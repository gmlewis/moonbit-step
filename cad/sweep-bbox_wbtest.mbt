///|
/// A square profile revolved one turn on a 10 mm helix radius with no axial
/// pitch forms a square-section torus. Its bounding box is exact: 9..11 mm
/// radially and 0..1 mm axially. The former implementation expanded the path
/// by a fixed 5 mm, which would give 15 mm and -5..5 mm.
test "swept profile bounding box is tight" {
  let path = helix_path(
    pos=(0.0, 0.0, 0.0),
    size_per_turn=(10.0, 10.0, 0.0),
    num_turns=1.0,
    num_segs_per_turn=36,
    start_angle=0.0,
    clockwise=true,
  )
  let profile = SweepProfile::new(
    [(1.0, 0.0, 0.0), (1.0, 0.0, 1.0), (-1.0, 0.0, 1.0), (-1.0, 0.0, 0.0)],
    normal_dir=(0.0, 1.0, 0.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  let shape = SweptProfile::new(path~, profile~, straight_outline=false)
  let (x0, x1, y0, y1, z0, z1) = shape.bounding_box()
  let tol = 1.0e-9
  assert_true((x0 + 11.0).abs() < tol)
  assert_true((x1 - 11.0).abs() < tol)
  assert_true((y0 + 11.0).abs() < tol)
  assert_true((y1 - 11.0).abs() < tol)
  assert_true(z0.abs() < tol)
  assert_true((z1 - 1.0).abs() < tol)
}

///|
/// An empty path has no extent and must not return the sentinel min/max
/// values.
test "empty swept profile bounding box is degenerate" {
  let path = helix_path(num_turns=0.0, num_segs_per_turn=8)
  let profile = SweepProfile::new([
    (1.0, 0.0, 0.0),
    (0.0, 0.0, 1.0),
    (-1.0, 0.0, 0.0),
  ])
  let shape = SweptProfile::new(path~, profile~)
  let (x0, x1, y0, y1, z0, z1) = shape.bounding_box()
  assert_true(x0 == 0.0 && x1 == 0.0)
  assert_true(y0 == 0.0 && y1 == 0.0)
  assert_true(z0 == 0.0 && z1 == 0.0)
}
