///|
test "GT2 tooth outline has no duplicate consecutive points" {
  let geom = match gt2_geometry(20) {
    Ok(g) => g
    Err(e) => abort(e.message())
  }
  let points = gt2_tooth_outline(geom)
  assert_true(points.length() > 0)
  for i in 0..<points.length() {
    let a = points[i]
    let b = points[(i + 1) % points.length()]
    if (a.0 - b.0).abs() < 1.0e-12 && (a.1 - b.1).abs() < 1.0e-12 {
      fail("duplicate consecutive GT2 outline point at \{i}")
    }
  }
}
