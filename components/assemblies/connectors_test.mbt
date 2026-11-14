///|
test "plate_with_hole exposes face and hole connectors" {
  let part = match @assemblies.plate_with_hole(50.0, 40.0, 6.0, 5.5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let names = part.connectors().map(fn(c) { c.name })
  assert_true(names.contains("face-top"))
  assert_true(names.contains("face-bottom"))
  assert_true(names.contains("hole-1"))
}
