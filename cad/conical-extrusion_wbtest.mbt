///|
fn ce_close(actual : Double, expected : Double) -> Unit {
  let tol = 1.0e-9 * (1.0 + expected.abs())
  if !((actual - expected).abs() <= tol) {
    abort("expected \{expected}, got \{actual} (tol \{tol})")
  }
}

///|
test "conical extrusion tapers a square to half scale" {
  let outer = Profile2D::centered_rect(20.0, 20.0)
  let shape = ConicalExtrusion::new(outer, 4.0, 8.0)
  let (x0, x1, y0, y1, z0, z1) = shape.bounding_box()
  ce_close(x0, -10.0)
  ce_close(x1, 10.0)
  ce_close(y0, -10.0)
  ce_close(y1, 10.0)
  ce_close(z0, 0.0)
  ce_close(z1, 4.0)
  // A0 = 400, h = 4, k = (8 - 4) / 8 = 0.5:
  // V = A0 * h * (1 + k + k^2) / 3.
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  ce_close(volume, 400.0 * 4.0 * 1.75 / 3.0)
  let top = match shape.section_at_local(4.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  ce_close(top.area_mm2, 100.0)
  ce_close(top.perimeter_mm, 40.0)
  ce_close(top.outer_radius_mm, 5.0 * Double::sqrt(2.0))
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  ce_close(centroid.0, 0.0)
  ce_close(centroid.1, 0.0)
  ce_close(centroid.2, 11.0 / 7.0)
  let step = Design::new(name="conical")
    .add(shape.with_name("taper"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 6)
  assert_eq(rev_count(step, "PLANE("), 6)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 0)
  assert_eq(rev_count(step, "B_SPLINE_SURFACE"), 0)
}

///|
test "conical extrusion bore stays cylindrical while the body tapers" {
  let outer = Profile2D::centered_rect(20.0, 20.0)
  let shape = ConicalExtrusion::new(
    outer,
    4.0,
    8.0,
    round_bore=((0.0, 0.0), 6.0),
  )
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  ce_close(volume, 400.0 * 4.0 * 1.75 / 3.0 - @math.PI * 9.0 * 4.0)
  // At z = 2 the body is scaled by 0.75; the bore is unchanged.
  let mid = match shape.section_at_local(2.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  ce_close(mid.area_mm2, 400.0 * 0.75 * 0.75 - @math.PI * 9.0)
  ce_close(mid.perimeter_mm, 80.0 * 0.75 + 2.0 * @math.PI * 3.0)
  assert_eq(mid.rings.length(), 1)
  ce_close(mid.rings[0].outer_radius_mm, 3.0)
  let step = Design::new(name="conical-bore")
    .add(shape.with_name("taper"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 7)
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(rev_count(step, "CIRCLE("), 2)
  assert_eq(rev_count(step, "CONICAL_SURFACE("), 0)
}

///|
test "conical extrusion scales a polygonal hole" {
  let outer = Profile2D::centered_rect(20.0, 20.0)
  let hole = Profile2D::centered_rect(4.0, 4.0)
  let shape = ConicalExtrusion::new(outer, 4.0, 8.0, holes=[hole])
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  ce_close(volume, (400.0 - 16.0) * 4.0 * 1.75 / 3.0)
  let top = match shape.section_at_local(4.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  ce_close(top.area_mm2, 96.0)
  ce_close(top.perimeter_mm, 48.0)
  assert_eq(top.rings.length(), 1)
  ce_close(top.rings[0].outer_radius_mm, Double::sqrt(2.0))
  let step = Design::new(name="conical-hole")
    .add(shape.with_name("taper"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 10)
  assert_eq(rev_count(step, "CYLINDRICAL_SURFACE("), 0)
}

///|
test "conical extrusion normalizes a clockwise outer loop" {
  let outer = Profile2D::centered_rect(20.0, 20.0).rev()
  let shape = ConicalExtrusion::new(outer, 4.0, 8.0)
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  ce_close(volume, 400.0 * 4.0 * 1.75 / 3.0)
  let step = Design::new(name="conical-cw")
    .add(shape.with_name("taper"))
    .to_step_file()
  assert_eq(rev_count(step, "ADVANCED_FACE("), 6)
}

///|
test "conical extrusion rejects an apex at or below the small end" {
  let flat = ConicalExtrusion::new(
    Profile2D::centered_rect(20.0, 20.0),
    4.0,
    4.0,
  )
  assert_true(
    match flat.analysis_volume() {
      Ok(_) => false
      Err(_) => true
    },
  )
  assert_true(
    match flat.analysis_mesh() {
      Ok(_) => false
      Err(_) => true
    },
  )
  let over = ConicalExtrusion::new(
    Profile2D::centered_rect(20.0, 20.0),
    4.0,
    2.0,
  )
  assert_true(
    match over.analysis_volume() {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "conical extrusion section outside the face width is empty" {
  let shape = ConicalExtrusion::new(
    Profile2D::centered_rect(20.0, 20.0),
    4.0,
    8.0,
  )
  assert_true(
    match shape.section_at_local(-0.5) {
      Ok(_) => false
      Err(_) => true
    },
  )
  assert_true(
    match shape.section_at_local(4.5) {
      Ok(_) => false
      Err(_) => true
    },
  )
}

///|
test "conical extrusion mesh covers both ends" {
  let shape = ConicalExtrusion::new(
    Profile2D::centered_rect(20.0, 20.0),
    4.0,
    8.0,
    round_bore=((0.0, 0.0), 6.0),
  )
  let (verts, faces) = match shape.analysis_mesh() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_eq(verts.length(), 8 + 2 * 32)
  assert_eq(faces.length(), 4 + 2 * 2 + 32)
}

///|
test "conical extrusion public methods mirror the shape analysis" {
  let e = ConicalExtrusion::{
    profile: { outer: Profile2D::centered_rect(20.0, 20.0), holes: [], },
    height_mm: 4.0,
    apex_distance_mm: 8.0,
    round_bore: None,
  }
  ce_close(e.volume(), 400.0 * 4.0 * 1.75 / 3.0)
  let section = match e.section_at(2.0) {
    Ok(s) => s
    Err(err) => abort(err.message())
  }
  ce_close(section.area_mm2, 225.0)
}
