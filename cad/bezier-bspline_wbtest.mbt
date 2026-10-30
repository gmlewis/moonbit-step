///|
/// bs_k is the cubic Bezier control-point offset that approximates a quarter
/// circle: (4/3) * tan(pi/8).
let bs_k : Double = 0.5522847498307936

///|
fn bs_straight_anchor(x : Double, y : Double) -> BezierAnchor {
  { position: (x, y), handle_in: (x, y), handle_out: (x, y), }
}

///|
fn bs_straight_square(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  clear~ : Bool,
) -> BezierPath {
  {
    anchors: [
      bs_straight_anchor(x0, y0),
      bs_straight_anchor(x1, y0),
      bs_straight_anchor(x1, y1),
      bs_straight_anchor(x0, y1),
    ],
    closed: true,
    clear,
  }
}

///|
/// bs_circle_path builds four cubic Bezier quarter arcs that approximate a
/// circle centered at `c` with radius `r`.
fn bs_circle_path(r : Double, c : Vec2, clear~ : Bool) -> BezierPath {
  let (cx, cy) = c
  let k = r * bs_k
  let anchors = [
    {
      position: (cx + r, cy),
      handle_in: (cx + r, cy - k),
      handle_out: (cx + r, cy + k),
    },
    {
      position: (cx, cy + r),
      handle_in: (cx + k, cy + r),
      handle_out: (cx - k, cy + r),
    },
    {
      position: (cx - r, cy),
      handle_in: (cx - r, cy + k),
      handle_out: (cx - r, cy - k),
    },
    {
      position: (cx, cy - r),
      handle_in: (cx - k, cy - r),
      handle_out: (cx + k, cy - r),
    },
  ]
  { anchors, closed: true, clear, }
}

///|
test "curved bezier profile emits bspline geometry" {
  let circle = bs_circle_path(5.0, (0.0, 0.0), clear=false)
  let step = Design::new(name="bez-plate")
    .add(ExtrudedBezierProfile::new([circle], 2.0).with_name("plate"))
    .to_step_file()
  assert_true(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  assert_true(step.contains("SURFACE_OF_LINEAR_EXTRUSION("))
  // One lateral surface plus two planar caps.
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="3")
  // One profile curve for the bottom cap and one for the top cap.
  inspect(step.split("B_SPLINE_CURVE_WITH_KNOTS(").count() - 1, content="2")
  // Only the vertical seam remains a line.
  inspect(step.split("LINE(").count() - 1, content="1")
}

///|
test "bspline extrudes to exact extents" {
  let r = 5.0
  let h = 3.0
  let circle = bs_circle_path(r, (0.0, 0.0), clear=false)
  let step = Design::new(name="disk")
    .add(ExtrudedBezierProfile::new([circle], h).with_name("disk"))
    .to_step_file()
  let pts = step_points(step)
  assert_true(pts.length() > 0)
  let (min, max) = points_bounds(pts)
  assert_near(min.0, -r)
  assert_near(max.0, r)
  assert_near(min.1, -r)
  assert_near(max.1, r)
  assert_near(min.2, 0.0)
  assert_near(max.2, h)
}

///|
test "bspline hole keeps opposite orientation" {
  let outer = bs_straight_square(0.0, 0.0, 10.0, 10.0, clear=false)
  let hole = bs_circle_path(2.0, (5.0, 5.0), clear=true)
  let step = Design::new(name="plate")
    .add(ExtrudedBezierProfile::new([outer, hole], 2.0).with_name("plate"))
    .to_step_file()
  assert_false(step.contains("CLOSED_SHELL('',())"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  // Bottom and top caps each have one outer bound; both caps also carry one
  // hole bound, so exactly two FACE_BOUNDs exist.
  inspect(step.split("FACE_BOUND(").count() - 1, content="2")
  // Two caps plus one lateral surface per contour.
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="4")
  inspect(step.split("SURFACE_OF_LINEAR_EXTRUSION(").count() - 1, content="2")
}

///|
test "straight bezier profile keeps polyline output" {
  let outer = bs_straight_square(0.0, 0.0, 10.0, 10.0, clear=false)
  let step = Design::new(name="square-plate")
    .add(ExtrudedBezierProfile::new([outer], 2.0).with_name("plate"))
    .to_step_file()
  assert_false(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  assert_true(step.contains("LINE("))
  // Two caps plus four flat sides, exactly as before.
  inspect(step.split("ADVANCED_FACE(").count() - 1, content="6")
}

///|
test "extruded polyline profile is unchanged" {
  let profile = Profile2D::circle(10.0, segments=16)
  let step = Design::new(name="poly")
    .add(ExtrudedProfile::new(profile, 2.0).with_name("p"))
    .to_step_file()
  assert_false(step.contains("B_SPLINE_CURVE_WITH_KNOTS("))
  assert_true(step.contains("LINE("))
}
