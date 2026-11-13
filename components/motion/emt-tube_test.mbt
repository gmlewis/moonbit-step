///|
fn emt_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn has_emt_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "EMT 1/2 in tube uses the measured outside diameter, not the trade size" {
  let size = match @motion.emt_size("1/2") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(emt_close(size.outside_diameter_mm, 17.9324, 1.0e-9))
  assert_true(emt_close(size.wall_mm, 1.0668, 1.0e-9))
  let part = match @motion.emt_tube(size, 304.8) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(emt_close(x0, -8.9662, 1.0e-9))
  assert_true(emt_close(x1, 8.9662, 1.0e-9))
  assert_true(emt_close(y0, -8.9662, 1.0e-9))
  assert_true(emt_close(y1, 8.9662, 1.0e-9))
  assert_true(emt_close(z0, 0.0, 1.0e-9))
  assert_true(emt_close(z1, 304.8, 1.0e-9))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // Two annular end planes, an outside cylinder, and a bore.
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.cylinder, 2)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let id = 17.9324 - 2.0 * 1.0668
  let expected = 3.141592653589793 / 4.0 * (17.9324 * 17.9324 - id * id) * 304.8
  assert_true(emt_close(volume, expected, 0.5))
}

///|
test "EMT tube exposes both bores, both outer ends, and both end faces" {
  let size = match @motion.emt_size("3/4") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.emt_tube(size, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_emt_connector(part, "bore-a"))
  assert_true(has_emt_connector(part, "bore-b"))
  assert_true(has_emt_connector(part, "outer-a"))
  assert_true(has_emt_connector(part, "outer-b"))
  assert_true(has_emt_connector(part, "end-a"))
  assert_true(has_emt_connector(part, "end-b"))
  let bore = match part.connector("bore-a") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(
    emt_close(bore.diameter_mm.unwrap(), 23.4188 - 2.0 * 1.2446, 1.0e-9),
  )
}

///|
test "EMT rejects unknown trade sizes and zero length" {
  assert_true(@motion.emt_size("2-1/2") is Err(_))
  let size = match @motion.emt_size("1/2") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(@motion.emt_tube(size, 0.0) is Err(_))
}
