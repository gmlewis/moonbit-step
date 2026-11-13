///|
fn vslot_tnut_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn has_vslot_tnut_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
test "OpenBuilds M5 drop-in T-nut boundary and bore" {
  let spec = @fasteners.SlotTNutSpec::openbuilds_m5()
  let part = match @fasteners.vslot_t_nut(spec) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(vslot_tnut_close(x0, -5.0, 1.0e-9))
  assert_true(vslot_tnut_close(x1, 5.0, 1.0e-9))
  assert_true(vslot_tnut_close(y0, -3.0, 1.0e-9))
  assert_true(vslot_tnut_close(y1, 3.0, 1.0e-9))
  assert_true(vslot_tnut_close(z0, 0.0, 1.0e-9))
  assert_true(vslot_tnut_close(z1, 4.4, 1.0e-9))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // Two semicircular end arcs and four tap-drill bore arcs; two caps and two
  // straight sides. The STEP compiler merges the bore loop into one cylinder.
  assert_eq(inventory.cylinder, 6)
  assert_eq(inventory.plane, 4)
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let obround = (10.0 - 6.0) * 6.0 + 3.141592653589793 * 3.0 * 3.0
  let expected = (obround - 3.141592653589793 * 2.1 * 2.1) * 4.4
  assert_true(vslot_tnut_close(volume, expected, 0.05))
}

///|
test "T-nut exposes thread, seat, and slot engagement" {
  let part = match
    @fasteners.vslot_t_nut(@fasteners.SlotTNutSpec::openbuilds_m5()) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(has_vslot_tnut_connector(part, "thread"))
  assert_true(has_vslot_tnut_connector(part, "seat-face"))
  assert_true(has_vslot_tnut_connector(part, "slot-engagement"))
  let thread = match part.connector("thread") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(thread.kind.to_string(), "threaded")
  assert_eq(thread.gender.to_string(), "female")
  assert_true(vslot_tnut_close(thread.diameter_mm.unwrap(), 5.0, 1.0e-12))
}

///|
test "T-nut validates its own proportions" {
  let bad = @fasteners.SlotTNutSpec::{
    designation: "bad",
    length_mm: 6.0,
    width_mm: 6.0,
    height_mm: 4.4,
    thread_diameter_mm: 5.0,
    tap_drill_mm: 4.2,
  }
  assert_true(@fasteners.vslot_t_nut(bad) is Err(_))
}
