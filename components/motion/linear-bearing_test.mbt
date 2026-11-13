///|
fn linear_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
test "LM-series size table" {
  let size = match @motion.linear_bearing_size("lm8uu") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_eq(size.designation, "LM8UU")
  assert_true(linear_close(size.bore_mm, 8.0))
  assert_true(linear_close(size.outer_mm, 15.0))
  assert_true(linear_close(size.length_mm, 24.0))
  assert_true(@motion.linear_bearing_size("LM99UU") is Err(_))
  assert_eq(@motion.linear_bearing_designations().length(), 6)
}

///|
test "LM8UU envelope dimensions" {
  let size = match @motion.linear_bearing_size("LM8UU") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.linear_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(linear_close(x0, -7.5))
  assert_true(linear_close(x1, 7.5))
  assert_true(linear_close(y0, -7.5))
  assert_true(linear_close(y1, 7.5))
  assert_true(linear_close(z0, 0.0))
  assert_true(linear_close(z1, 24.0))
  assert_eq(part.layers().length(), 1)
  assert_true(part.features().modeled.contains("bore"))
  assert_true(part.features().omitted.length() >= 3)

  let centered = match @motion.linear_bearing(size, orient_to_reference=true) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (_cx0, _cx1, _cy0, _cy1, cz0, cz1) = centered.bounding_box()
  assert_true(linear_close(cz0, -12.0))
  assert_true(linear_close(cz1, 12.0))
}

///|
test "flanged LM8UU housing dimensions" {
  let size = match @motion.linear_bearing_size("LM8UU") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.flanged_linear_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(linear_close(x0, -12.375))
  assert_true(linear_close(x1, 12.375))
  assert_true(linear_close(y0, -12.375))
  assert_true(linear_close(y1, 12.375))
  assert_true(linear_close(z0, 0.0))
  assert_true(linear_close(z1, 26.7))
  assert_eq(part.layers().length(), 1)

  let oriented = match
    @motion.flanged_linear_bearing(size, orient_to_reference=true) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (ox0, ox1, oy0, oy1, oz0, oz1) = oriented.bounding_box()
  assert_true(linear_close(ox0, -14.7))
  assert_true(linear_close(ox1, 12.0))
  assert_true(linear_close(oy0, -12.375))
  assert_true(linear_close(oy1, 12.375))
  assert_true(linear_close(oz0, -12.375))
  assert_true(linear_close(oz1, 12.375))
}

///|
test "linear bearing rejects invalid parameters" {
  let size = match @motion.linear_bearing_size("LM8UU") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(
    @motion.flanged_linear_bearing(size, flange_diameter_mm=14.0) is Err(_),
  )
  assert_true(
    @motion.flanged_linear_bearing(size, flange_thickness_mm=0.0) is Err(_),
  )
  let bad : @motion.LinearBearingSize = @motion.LinearBearingSize::{
    designation: "BAD",
    bore_mm: 8.0,
    outer_mm: 8.0,
    length_mm: 24.0,
  }
  assert_true(@motion.linear_bearing(bad) is Err(_))
}
