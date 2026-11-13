///|
fn vwheel_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn has_vwheel_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "OpenBuilds solid V-wheel matches the reference boundary" {
  let spec = @motion.VWheelSpec::openbuilds_solid_v()
  let part = match @motion.v_wheel(spec) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(vwheel_close(x0, -11.945, 1.0e-3))
  assert_true(vwheel_close(x1, 11.945, 1.0e-3))
  assert_true(vwheel_close(y0, -11.945, 1.0e-3))
  assert_true(vwheel_close(y1, 11.945, 1.0e-3))
  assert_true(vwheel_close(z0, 0.0, 1.0e-3))
  assert_true(vwheel_close(z1, 10.23, 1.0e-3))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // Four planar faces, two bearing pockets plus two outer cylinders plus the
  // mid-lip bore, and the two 45 degree V-groove cones.
  assert_eq(inventory.plane, 4)
  assert_eq(inventory.cylinder, 5)
  assert_eq(inventory.cone, 2)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // The CC BY 4.0 Xem Studio reference measures 1934.87 mm^3.
  assert_true(vwheel_close(volume, 1934.87, 0.5))
}

///|
test "V-wheel exposes seats, axle bore, groove datum, and faces" {
  let part = match @motion.v_wheel(@motion.VWheelSpec::openbuilds_solid_v()) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_vwheel_connector(part, "axle-bore"))
  assert_true(has_vwheel_connector(part, "bearing-seat-a"))
  assert_true(has_vwheel_connector(part, "bearing-seat-b"))
  assert_true(has_vwheel_connector(part, "v-groove"))
  assert_true(has_vwheel_connector(part, "face-a"))
  assert_true(has_vwheel_connector(part, "face-b"))
  let seat = match part.connector("bearing-seat-a") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(vwheel_close(seat.diameter_mm.unwrap(), 16.0, 1.0e-12))
  let groove = match part.connector("v-groove") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(vwheel_close(groove.diameter_mm.unwrap(), 17.49, 1.0e-12))
}

///|
test "V-wheel rejects impossible proportions" {
  let bad = @motion.VWheelSpec::{
    designation: "bad",
    outer_diameter_mm: 10.0,
    width_mm: 10.0,
    groove_min_diameter_mm: 15.0,
    bearing_seat_diameter_mm: 8.0,
    axle_bore_mm: 5.0,
    mid_lip_mm: 1.0,
  }
  assert_true(@motion.v_wheel(bad) is Err(_))
}
