///|
/// Pure helper tests for example 12.
///
/// These use `inspect(...)` snapshots so `moon test -u` can update expected values.

///|
test "vertex_at_cardinal_angles" {
  let center = (0.0, 0.0)
  inspect(vertex_at(center~, radius=2.0, angle=0.0), content="(2, 0)")
  inspect(
    vertex_at(center~, radius=2.0, angle=@math.PI / 2),
    content="(1.2246467991473532e-16, 2)",
  )
  inspect(
    vertex_at(center~, radius=2.0, angle=@math.PI),
    content="(-2, 2.4492935982947064e-16)",
  )
}

///|
test "vector_length_3_4_5" {
  inspect(vector_length((0.0, 0.0), (3.0, 4.0)), content="5")
}

///|
test "center_of_face_square" {
  let pts = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]
  inspect(center_of_face(pts), content="(0, 0)")
}

///|
test "solve_for_t_linear" {
  // f(t) = 10 + 20t => d=15 should yield t=0.25
  let f = fn(t) { 10.0 + 20.0 * t }
  inspect(solve_for_t(15.0, f), content="0.25")
  inspect(solve_for_t(9.0, f), content="-1")
  inspect(solve_for_t(40.5, f), content="2")
}
