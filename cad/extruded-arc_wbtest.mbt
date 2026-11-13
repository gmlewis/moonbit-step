///|
fn arc_count_sub(haystack : String, needle : String) -> Int32 {
  haystack.split(needle).collect().length() - 1
}

///|
fn keyed_test_profile() -> Array[ProfileSegment] {
  let radius = 5.0
  let hw = 1.5
  let y_top = Double::sqrt(radius * radius - hw * hw)
  let y_bottom = radius - 1.5
  [
    SegmentArc((-hw, y_top), (0.0, -radius), (0.0, 0.0)),
    SegmentArc((0.0, -radius), (hw, y_top), (0.0, 0.0)),
    SegmentLine((hw, y_top), (hw, y_bottom)),
    SegmentLine((hw, y_bottom), (-hw, y_bottom)),
    SegmentLine((-hw, y_bottom), (-hw, y_top)),
  ]
}

///|
test "arc profile has analytic cylinder faces and exact volume" {
  let profile = ExtrudedArcProfile::new(keyed_test_profile(), 40.0)
  assert_true(profile.validate())
  let shape = profile.as_shape()
  let inventory = shape.surface_inventory()
  assert_eq(inventory.plane, 5)
  assert_eq(inventory.cylinder, 2)
  assert_eq(inventory.cone, 0)
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true((volume - 2970.718239149312).abs() < TEST_VALUE_EPS)
  let centroid = match shape.analysis_centroid() {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(centroid.0.abs() < TEST_LENGTH_EPS)
  // The keyway removes material on +Y, so the centroid drops below the axis.
  assert_true((centroid.1 + 0.2423656308133004).abs() < TEST_VALUE_EPS)
  assert_true((centroid.2 - 20.0).abs() < TEST_LENGTH_EPS)
  let section = match shape.section_at_local(5.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true((section.area_mm2 - 74.2679559787328).abs() < TEST_VALUE_EPS)
  assert_true((section.perimeter_mm - 33.90839200991341).abs() < TEST_VALUE_EPS)
  assert_true((section.outer_radius_mm - 5.0).abs() < TEST_LENGTH_EPS)
}

///|
fn holed_test_profile() -> (Array[ProfileSegment], Array[ProfileSegment]) {
  let outer : Array[ProfileSegment] = [
    SegmentLine((5.0, -5.0), (5.0, 5.0)),
    SegmentLine((5.0, 5.0), (-5.0, 5.0)),
    SegmentLine((-5.0, 5.0), (-5.0, -5.0)),
    SegmentLine((-5.0, -5.0), (5.0, -5.0)),
  ]
  let hole : Array[ProfileSegment] = [
    SegmentArc((2.0, 0.0), (0.0, 2.0), (0.0, 0.0)),
    SegmentArc((0.0, 2.0), (-2.0, 0.0), (0.0, 0.0)),
    SegmentArc((-2.0, 0.0), (0.0, -2.0), (0.0, 0.0)),
    SegmentArc((0.0, -2.0), (2.0, 0.0), (0.0, 0.0)),
  ]
  (outer, hole)
}

///|
test "arc profile supports analytic inner loops" {
  let (outer, hole) = holed_test_profile()
  let profile = ExtrudedArcProfile::new(outer, 10.0, holes=[hole])
  assert_true(profile.validate())
  let shape = profile.as_shape()
  let inventory = shape.surface_inventory()
  assert_eq(inventory.plane, 6)
  assert_eq(inventory.cylinder, 4)
  let volume = match shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true((volume - (100.0 - 4.0 * @math.PI) * 10.0).abs() < TEST_VALUE_EPS)
  let section = match shape.section_at_local(5.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(
    (section.area_mm2 - (100.0 - 4.0 * @math.PI)).abs() < TEST_VALUE_EPS,
  )
  assert_true(
    (section.perimeter_mm - (40.0 + 4.0 * @math.PI)).abs() < TEST_VALUE_EPS,
  )
  assert_true((section.inner_radius_mm - 2.0).abs() < TEST_LENGTH_EPS)
}

///|
test "arc profile with an inner loop compiles one closed solid" {
  let (outer, hole) = holed_test_profile()
  let profile = ExtrudedArcProfile::new(outer, 10.0, holes=[hole])
  let step = Design::new(name="holed")
    .add(profile.as_shape().with_name("holed"))
    .to_step_file()
  // The full circular hole is emitted as one analytic cylinder with a single
  // seam: four outer side planes + two cap planes + one hole cylinder.
  assert_eq(arc_count_sub(step, "ADVANCED_FACE("), 7)
  assert_eq(arc_count_sub(step, "PLANE("), 6)
  assert_eq(arc_count_sub(step, "CYLINDRICAL_SURFACE("), 1)
  assert_eq(arc_count_sub(step, "CLOSED_SHELL("), 1)
}

///|
test "arc profile compiles to one closed solid with two cylinders" {
  let profile = ExtrudedArcProfile::new(keyed_test_profile(), 40.0)
  let step = Design::new(name="keyed")
    .add(profile.as_shape().with_name("keyed"))
    .to_step_file()
  assert_eq(arc_count_sub(step, "ADVANCED_FACE("), 7)
  assert_eq(arc_count_sub(step, "PLANE("), 5)
  assert_eq(arc_count_sub(step, "CYLINDRICAL_SURFACE("), 2)
  assert_eq(arc_count_sub(step, "CLOSED_SHELL("), 1)
  assert_eq(arc_count_sub(step, "MANIFOLD_SOLID_BREP("), 1)
}
