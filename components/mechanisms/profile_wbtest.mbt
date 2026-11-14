///|
test "linear rail section is a valid counter-clockwise extrusion" {
  let profile = match
    linear_rail_profile(
      width_mm=20.0,
      height_mm=15.0,
      groove_width_mm=6.0,
      groove_depth_mm=2.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let section = linear_rail_section(profile)
  let shape = @cad.ExtrudedArcProfile::new(section, 100.0)
  assert_true(shape.validate())
  let points : Array[(Double, Double)] = []
  for segment in section {
    match segment {
      @cad.SegmentLine(start, _) => points.push(start)
      @cad.SegmentArc(start, _, _) => points.push(start)
    }
  }
  assert_true(@cad.polygon_area_2d(points) > 0.0)
}
