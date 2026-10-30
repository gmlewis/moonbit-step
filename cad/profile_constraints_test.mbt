///|
/// Black-box tests for the deterministic Profile2D constraint helpers.
///
/// Every helper returns concrete coordinates, so these assertions are exact
/// (or exact to floating-point noise) and output stays diffable.

///|
fn dist2(a : @cad.Vec2, b : @cad.Vec2) -> Double {
  let (ax, ay) = a
  let (bx, by) = b
  ((ax - bx) * (ax - bx) + (ay - by) * (ay - by)).sqrt()
}

///|
test "bolt_circle places holes on a radius at even angles" {
  let pts = @cad.bolt_circle(4, 10.0)
  inspect(pts.length(), content="4")
  assert_approx_eq(pts[0].0, 10.0)
  assert_approx_eq(pts[0].1, 0.0)
  assert_approx_eq(pts[1].0, 0.0)
  assert_approx_eq(pts[1].1, 10.0)
  assert_approx_eq(pts[2].0, -10.0)
  assert_approx_eq(pts[2].1, 0.0)
  assert_approx_eq(pts[3].0, 0.0)
  assert_approx_eq(pts[3].1, -10.0)
  for p in pts {
    assert_approx_eq(dist2(p, (0.0, 0.0)), 10.0)
  }
}

///|
test "bolt_circle honours the start angle" {
  let pts = @cad.bolt_circle(4, 10.0, start_angle_deg=45.0)
  assert_approx_eq(pts[0].0, 7.0710678118654755)
  assert_approx_eq(pts[0].1, 7.0710678118654755)
  assert_approx_eq(dist2(pts[0], (0.0, 0.0)), 10.0)
}

///|
test "point_on_circle is deterministic" {
  let p = @cad.point_on_circle(5.0, 0.0)
  inspect(p.0, content="5")
  inspect(p.1, content="0")
  let q = @cad.point_on_circle(5.0, 180.0)
  assert_approx_eq(q.0, -5.0)
  assert_approx_eq(q.1, 0.0)
}

///|
test "grid_of_holes is centered and row-major" {
  let pts = @cad.grid_of_holes(3, 2, 10.0, 5.0)
  inspect(pts.length(), content="6")
  assert_approx_eq(pts[0].0, -10.0)
  assert_approx_eq(pts[0].1, -2.5)
  assert_approx_eq(pts[1].0, 0.0)
  assert_approx_eq(pts[1].1, -2.5)
  assert_approx_eq(pts[2].0, 10.0)
  assert_approx_eq(pts[2].1, -2.5)
  assert_approx_eq(pts[3].0, -10.0)
  assert_approx_eq(pts[3].1, 2.5)
  assert_approx_eq(pts[5].0, 10.0)
  assert_approx_eq(pts[5].1, 2.5)
}

///|
test "midpoint and line projection are exact" {
  let m = @cad.midpoint((0.0, 0.0), (10.0, 4.0))
  inspect(m.0, content="5")
  inspect(m.1, content="2")
  let a = @cad.project_point_to_line((5.0, 3.0), (0.0, 0.0), (10.0, 0.0))
  inspect(a.0, content="5")
  inspect(a.1, content="0")
  let b = @cad.project_point_to_line((2.0, 9.0), (2.0, 0.0), (2.0, 5.0))
  inspect(b.0, content="2")
  inspect(b.1, content="9")
  // A degenerate line collapses to its single point.
  let c = @cad.project_point_to_line((3.0, 3.0), (1.0, 1.0), (1.0, 1.0))
  inspect(c.0, content="1")
  inspect(c.1, content="1")
}

///|
test "centered_circle matches circle" {
  let a = @cad.Profile2D::centered_circle(10.0, segments=8)
  let b = @cad.Profile2D::circle(10.0, segments=8)
  inspect(a.length(), content="8")
  for i in 0..<a.length() {
    assert_approx_eq(a[i].0, b[i].0)
    assert_approx_eq(a[i].1, b[i].1)
    assert_approx_eq(dist2(a[i], (0.0, 0.0)), 5.0)
  }
}

///|
test "tangent_rect matches a rounded rect" {
  let a = @cad.Profile2D::tangent_rect(20.0, 10.0, 3.0, segments=8)
  let b = @cad.Profile2D::rounded_rect(20.0, 10.0, 3.0, segments=8)
  inspect(a.length() == b.length(), content="true")
  for i in 0..<a.length() {
    assert_approx_eq(a[i].0, b[i].0)
    assert_approx_eq(a[i].1, b[i].1)
  }
}

///|
test "with_hole_at applies fit growth" {
  let plate = @cad.Profile2D::new(@cad.Profile2D::rect(40.0, 40.0)).with_hole_at(
    20.0,
    20.0,
    6.0,
    fit=@cad.Fit::Free,
    segments=16,
  )
  inspect(plate.holes.length(), content="1")
  inspect(plate.holes[0].length(), content="16")
  // Free adds 0.25 mm per face, so the radius grows from 3.0 to 3.25.
  for p in plate.holes[0] {
    assert_approx_eq(dist2(p, (20.0, 20.0)), 3.25)
  }
}

///|
test "with_holes_at and with_bolt_circle add one loop per location" {
  let locs = @cad.bolt_circle(6, 15.0)
  let plate = @cad.Profile2D::new(
    @cad.Profile2D::centered_circle(40.0, segments=32),
  ).with_bolt_circle(6, 15.0, 3.0, segments=12)
  inspect(plate.holes.length(), content="6")
  for i, hole in plate.holes {
    inspect(hole.length(), content="12")
    // Each hole is centered on its bolt-circle location.
    let c = locs[i]
    let mut sx = 0.0
    let mut sy = 0.0
    for p in hole {
      sx = sx + p.0
      sy = sy + p.1
    }
    let d = hole.length().to_double()
    assert_approx_eq(sx / d, c.0)
    assert_approx_eq(sy / d, c.1)
  }
}

///|
test "with_grid_of_holes adds cols*rows loops" {
  let plate = @cad.Profile2D::new(@cad.Profile2D::rect(100.0, 60.0)).with_grid_of_holes(
    3,
    2,
    20.0,
    15.0,
    4.0,
    segments=8,
  )
  inspect(plate.holes.length(), content="6")
}

///|
async test "a flange plate with a bolt circle passes the validator" {
  let plate = @cad.Profile2D::new(
      @cad.Profile2D::centered_circle(60.0, segments=64),
    )
    .with_hole_at(0.0, 0.0, 20.0, segments=48)
    .with_bolt_circle(6, 22.0, 5.0, segments=24)
  let design = @cad.Design::new(name="flange").add(
    @cad.ExtrudedProfile::new(plate.outer, 8.0, holes=plate.holes).with_name(
      "flange",
    ),
  )
  let dir = @fs.tmpdir(prefix="flange-")
  defer @fs.rmdir(dir, recursive=true)
  let out = dir + "/flange.step"
  @fs.write_file(
    out,
    @encoding/utf8.encode(design.to_step_file()),
    permission=0o644,
  )
  let code = @process.run(
    "python3",
    ["./scripts/validate_step.py", "--no-mesh", out],
    stdout=@stdio.stdout,
    stderr=@stdio.stderr,
  )
  inspect(code, content="0")
}
