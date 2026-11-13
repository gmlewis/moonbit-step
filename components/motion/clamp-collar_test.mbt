///|
/// Black-box tests for the one-piece clamp shaft collar.

///|
fn clamp_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn clamp_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "clamp collar is one boolean layer with a slit and clamp screw" {
  let part = match
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, screw_offset_mm=14.73) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 1)
  // The nominal intent keeps the chamfered annulus envelope; the evaluated
  // solid is trimmed by the slit (see the evaluated test).
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(clamp_close(x0, -20.0, 1.0e-9))
  assert_true(clamp_close(x1, 20.0, 1.0e-9))
  assert_true(clamp_close(y0, -20.0, 1.0e-9))
  assert_true(clamp_close(y1, 20.0, 1.0e-9))
  assert_true(clamp_close(z0, 0.0, 1.0e-9))
  assert_true(clamp_close(z1, 15.0, 1.0e-9))
  for
    name in [
      "bore", "outer-seat", "face-a", "face-b", "slit-datum", "clamp-screw-thread",
      "clamp-screw-hole", "head-seat",
    ] {
    if !clamp_has_connector(part, name) {
      abort("clamp collar is missing connector " + name)
    }
  }
  let thread = match part.connector("clamp-screw-thread") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  // The connector declares the M6 nominal diameter, not the clearance hole.
  assert_true(clamp_close(thread.diameter_mm.unwrap(), 6.0, 1.0e-9))
  let hole = match part.connector("clamp-screw-hole") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(clamp_close(hole.diameter_mm.unwrap(), 6.1, 1.0e-9))
  let seat = match part.connector("head-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(clamp_close(seat.diameter_mm.unwrap(), 10.2, 1.0e-9))
  // Reference head seat: the counterbore floor sits 6.4 mm inside the outside
  // surface along the screw axis.
  let (seat_x, seat_y, seat_z) = seat.placement.trans
  assert_true(clamp_close(seat_x, 7.1208, 0.02))
  assert_true(clamp_close(seat_y, 14.73, 1.0e-9))
  assert_true(clamp_close(seat_z, 7.5, 1.0e-9))
  let slit = match part.connector("slit-datum") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (_sx, sy, sz) = slit.placement.trans
  assert_true(clamp_close(sy, 14.73, 1.0e-9))
  assert_true(clamp_close(sz, 7.5, 1.0e-9))
}

///|
test "clamp collar defaults to a wall-midline M6 clamp screw" {
  let part = match @motion.clamp_shaft_collar(20.0, 40.0, 15.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let hole = match part.connector("clamp-screw-hole") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(clamp_close(hole.diameter_mm.unwrap(), 6.1, 1.0e-9))
  let seat = match part.connector("head-seat") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(clamp_close(seat.diameter_mm.unwrap(), 10.2, 1.0e-9))
  let (seat_x, seat_y, _) = seat.placement.trans
  // Wall midline offset 15.0: sqrt(20^2 - 15^2) - (6 + 0.4).
  assert_true(clamp_close(seat_y, 15.0, 1.0e-9))
  assert_true(clamp_close(seat_x, 6.8288, 1.0e-3))
}

///|
test "clamp collar rejects infeasible geometry" {
  // Outer diameter below the bore.
  assert_true(@motion.clamp_shaft_collar(40.0, 20.0, 15.0) is Err(_))
  // Negative chamfer.
  assert_true(
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, chamfer_mm=-0.1) is Err(_),
  )
  // Zero slit.
  assert_true(
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, slit_width_mm=0.0) is Err(_),
  )
  // Counterbore not larger than the clearance hole.
  assert_true(
    @motion.clamp_shaft_collar(
      20.0,
      40.0,
      15.0,
      drill_diameter_mm=6.1,
      counterbore_diameter_mm=5.0,
    )
    is Err(_),
  )
  // Clearance hole reaches into the bore.
  assert_true(
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, screw_offset_mm=8.0) is Err(_),
  )
  // Clearance hole breaks the outside diameter.
  assert_true(
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, screw_offset_mm=17.0) is Err(_),
  )
  // Counterbore reaches the shaft axis.
  assert_true(
    @motion.clamp_shaft_collar(20.0, 40.0, 15.0, screw_offset_mm=5.0) is Err(_),
  )
  // Hole wider than the collar width.
  assert_true(
    @motion.clamp_shaft_collar(
      20.0,
      40.0,
      10.0,
      drill_diameter_mm=6.1,
      counterbore_diameter_mm=11.0,
    )
    is Err(_),
  )
  // Head counterbore does not fit the +X jaw.
  assert_true(
    @motion.clamp_shaft_collar(
      20.0,
      100.0,
      15.0,
      drill_diameter_mm=0.8,
      counterbore_diameter_mm=2.0,
      screw_offset_mm=49.55,
    )
    is Err(_),
  )
}
