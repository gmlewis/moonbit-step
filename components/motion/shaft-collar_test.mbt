///|
fn shaft_collar_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn has_shaft_collar_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "shaft collar is an analytic chamfered annulus" {
  let part = match @motion.shaft_collar(10.0, 20.0, 10.0, chamfer_mm=0.5) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(shaft_collar_close(x0, -10.0, 1.0e-9))
  assert_true(shaft_collar_close(x1, 10.0, 1.0e-9))
  assert_true(shaft_collar_close(y0, -10.0, 1.0e-9))
  assert_true(shaft_collar_close(y1, 10.0, 1.0e-9))
  assert_true(shaft_collar_close(z0, 0.0, 1.0e-9))
  assert_true(shaft_collar_close(z1, 10.0, 1.0e-9))
  let inventory = part.layers()[0].shape.surface_inventory()
  assert_eq(inventory.plane, 2)
  assert_eq(inventory.cylinder, 2)
  assert_eq(inventory.cone, 4)
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // The sharp annulus would be 2356.19 mm^3; the four rim chamfers remove a
  // small amount, so the result is close to but below it.
  assert_true(volume < 2356.19)
  assert_true(volume > 2250.0)
}

///|
test "shaft collar exposes bore, outside seat, and faces" {
  let part = match @motion.shaft_collar(8.0, 16.0, 8.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_shaft_collar_connector(part, "bore"))
  assert_true(has_shaft_collar_connector(part, "outer-seat"))
  assert_true(has_shaft_collar_connector(part, "face-a"))
  assert_true(has_shaft_collar_connector(part, "face-b"))
  let bore = match part.connector("bore") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(shaft_collar_close(bore.diameter_mm.unwrap(), 8.0, 1.0e-12))
}

///|
test "shaft collar rejects an outer diameter below its bore" {
  assert_true(@motion.shaft_collar(20.0, 10.0, 8.0) is Err(_))
}

///|
test "set-screw collar is one boolean layer with a radial hole frame" {
  let part = match @motion.set_screw_shaft_collar(8.0, 16.0, 8.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 1)
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(shaft_collar_close(x0, -8.0, 1.0e-9))
  assert_true(shaft_collar_close(x1, 8.0, 1.0e-9))
  assert_true(shaft_collar_close(y0, -8.0, 1.0e-9))
  assert_true(shaft_collar_close(y1, 8.0, 1.0e-9))
  assert_true(shaft_collar_close(z0, 0.0, 1.0e-9))
  assert_true(shaft_collar_close(z1, 8.0, 1.0e-9))
  for
    name in [
      "bore", "outer-seat", "face-a", "face-b", "set-screw-thread", "set-screw-hole",
    ] {
    if !has_shaft_collar_connector(part, name) {
      abort("set-screw collar is missing connector " + name)
    }
  }
  let thread = match part.connector("set-screw-thread") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  // The connector declares the M5 nominal diameter, not the tap drill.
  assert_true(shaft_collar_close(thread.diameter_mm.unwrap(), 5.0, 1.0e-9))
  let hole = match part.connector("set-screw-hole") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // ISO metric M5 x 0.8 internal minor diameter = 4.1339746 mm.
  assert_true(shaft_collar_close(hole.diameter_mm.unwrap(), 4.1339746, 1.0e-6))
}

///|
test "set-screw collar accepts a measured drill diameter" {
  let part = match
    @motion.set_screw_shaft_collar(8.0, 16.0, 8.0, drill_diameter_mm=4.1) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let hole = match part.connector("set-screw-hole") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(shaft_collar_close(hole.diameter_mm.unwrap(), 4.1, 1.0e-12))
}

///|
test "set-screw collar rejects an oversized drill or chamfer" {
  // Wider than the collar width.
  assert_true(
    @motion.set_screw_shaft_collar(8.0, 24.0, 6.0, drill_diameter_mm=7.0)
    is Err(_),
  )
  // Wider than twice the collar wall.
  assert_true(
    @motion.set_screw_shaft_collar(8.0, 14.0, 12.0, drill_diameter_mm=7.0)
    is Err(_),
  )
  // Wider than the collar bore.
  assert_true(
    @motion.set_screw_shaft_collar(4.0, 16.0, 8.0, drill_diameter_mm=5.0)
    is Err(_),
  )
  assert_true(
    @motion.set_screw_shaft_collar(
      8.0,
      16.0,
      8.0,
      drill_diameter_mm=4.0,
      chamfer_mm=4.0,
    )
    is Err(_),
  )
  assert_true(@motion.set_screw_shaft_collar(20.0, 10.0, 8.0) is Err(_))
  assert_true(
    @motion.set_screw_shaft_collar(8.0, 16.0, 8.0, chamfer_mm=-0.1) is Err(_),
  )
}
