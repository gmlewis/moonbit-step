///|
fn closef(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn poly_area(pts : Array[Vec2]) -> Double {
  let n = pts.length()
  if n < 3 {
    return 0.0
  }
  let mut sum = 0.0
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    sum = sum + a.0 * b.1 - b.0 * a.1
  }
  sum / 2.0
}

///|
fn unwrap_profile(r : Result[Array[Vec2], ProfileOpError]) -> Array[Vec2] {
  match r {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
test "chamfer a unit square with a 0.1 chamfer on all four corners" {
  let square = Profile2D::rect(1.0, 1.0)
  assert_eq(square.length(), 4)
  let result = unwrap_profile(Profile2D::chamfer_vertices(square, 0.1))
  // Each corner is replaced by two points: 4 corners -> 8 points.
  assert_eq(result.length(), 8)
  // A 0.1 x 0.1 chamfer removes a right triangle of area 0.005 per corner.
  let expected = 1.0 - 4.0 * 0.5 * 0.1 * 0.1
  assert_true((poly_area(result) - expected).abs() < 1.0e-9)
  assert_true(Profile2D::is_simple(result))
}

///|
test "chamfer rejects an oversized offset" {
  let square = Profile2D::rect(1.0, 1.0)
  let result = Profile2D::chamfer_vertices(square, 0.6)
  inspect(result is Err(_), content="true")
}

///|
test "chamfer rejects a non-positive size" {
  let square = Profile2D::rect(1.0, 1.0)
  inspect(Profile2D::chamfer_vertices(square, 0.0) is Err(_), content="true")
  inspect(Profile2D::chamfer_vertices(square, -1.0) is Err(_), content="true")
}

///|
test "fillet a unit square corner with the analytic tangent distance" {
  let square = Profile2D::rect(1.0, 1.0)
  // A 90 degree corner with radius 0.2 has a tangent distance of 0.2.
  let result = unwrap_profile(
    Profile2D::fillet_vertices(square, 0.2, segments=8),
  )
  assert_true(result.length() > 4)
  // Area = 1.0 - 4 * (square corner area - quarter disc).
  let removed = 0.2 * 0.2 - 0.25 * @math.PI * 0.2 * 0.2
  let expected = 1.0 - 4.0 * removed
  assert_true((poly_area(result) - expected).abs() < 2.0e-3)
  assert_true(Profile2D::is_simple(result))
}

///|
test "fillet rejects a radius that does not fit" {
  let square = Profile2D::rect(1.0, 1.0)
  // Tangent distance equals the radius on a 90 degree corner; 0.6 overflows.
  inspect(Profile2D::fillet_vertices(square, 0.6) is Err(_), content="true")
}

///|
test "convex-only selection leaves the reflex vertex sharp" {
  // L-shaped, counter-clockwise: one reflex vertex at (1,1).
  let lshape : Array[Vec2] = [
    (0.0, 0.0),
    (2.0, 0.0),
    (2.0, 1.0),
    (1.0, 1.0),
    (1.0, 2.0),
    (0.0, 2.0),
  ]
  let result = unwrap_profile(
    Profile2D::chamfer_vertices(lshape, 0.1, which=ConvexOnly),
  )
  // Five convex vertices chamfered (2 points each) and one reflex kept.
  assert_eq(result.length(), 5 * 2 + 1)
  assert_true(Profile2D::is_simple(result))
}

///|
test "explicit index selection chamfers only the requested vertex" {
  let square = Profile2D::rect(1.0, 1.0)
  let result = unwrap_profile(
    Profile2D::chamfer_vertices(square, 0.1, which=Indices([0])),
  )
  assert_eq(result.length(), 5)
}

///|
test "clockwise input keeps its winding after chamfering" {
  let square = Profile2D::rect(1.0, 1.0).rev()
  let result = unwrap_profile(Profile2D::chamfer_vertices(square, 0.1))
  assert_true(poly_area(result) < 0.0)
}

///|
test "chamfer with an explicit angle produces an asymmetric leg" {
  let square = Profile2D::rect(1.0, 1.0)
  // Vertex 0 is (0,0) with prev (0,1) and next (1,0). The incoming leg is
  // 0.1; on a 90 degree corner a 30 degree chamfer gives an outgoing leg of
  // 0.1 * sin(30) / sin(120) = 0.0577.
  let result = unwrap_profile(
    Profile2D::chamfer_vertices(square, 0.1, angle_deg=30.0, which=Indices([0])),
  )
  assert_eq(result.length(), 5)
  let has_in = result.any(fn(p) { closef(p.1, 0.1) })
  let out_leg = 0.1 *
    @math.sin(30.0 * @math.PI / 180.0) /
    @math.sin(120.0 * @math.PI / 180.0)
  let has_out = result.any(fn(p) { closef(p.0, out_leg) })
  assert_true(has_in)
  assert_true(has_out)
}
