///|
fn hardware_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
test "extrusion T-nut M3 matches the reference envelope" {
  let spec = match @fasteners.extrusion_tnut_spec("M3", slot_width_mm=5.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @fasteners.extrusion_tnut(spec) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(hardware_close(x0, -3.175426480543))
  assert_true(hardware_close(x1, 3.175426480543))
  assert_true(hardware_close(y0, -2.75))
  assert_true(hardware_close(y1, 2.75))
  assert_true(hardware_close(z0, 0.0))
  assert_true(hardware_close(z1, 2.4))
  assert_eq(part.layers().length(), 1)
  assert_true(part.features().modeled.contains("hexagonal-prism"))
}

///|
test "extrusion T-nut M4 and M5 body sizes" {
  let m4 = match @fasteners.extrusion_tnut_spec("M4", slot_width_mm=5.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(hardware_close(m4.across_flats_mm, 7.0))
  assert_true(hardware_close(m4.thickness_mm, 3.2))
  let part4 = match @fasteners.extrusion_tnut(m4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, _z0, z1) = part4.bounding_box()
  assert_true(hardware_close(x0, -4.041451884327))
  assert_true(hardware_close(x1, 4.041451884327))
  assert_true(hardware_close(z1, 3.2))

  let m5 = match @fasteners.extrusion_tnut_spec("M5", slot_width_mm=6.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(hardware_close(m5.across_flats_mm, 8.0))
  assert_true(hardware_close(m5.thickness_mm, 4.0))
  assert_true(m5.hole_diameter_mm == 5.0)
}

///|
test "extrusion T-nut rejects impossible engagement" {
  assert_true(@fasteners.extrusion_tnut_spec("M3", slot_width_mm=6.0) is Err(_))
  assert_true(@fasteners.extrusion_tnut_spec("M6") is Err(_))
}

///|
test "M3 heat-set insert short and long envelopes" {
  let short = match @fasteners.heat_set_insert_m3("short") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = short.bounding_box()
  assert_true(hardware_close(x0, -3.24))
  assert_true(hardware_close(x1, 3.24))
  assert_true(hardware_close(y0, -3.24))
  assert_true(hardware_close(y1, 3.24))
  assert_true(hardware_close(z0, 0.0))
  assert_true(hardware_close(z1, 6.0))
  assert_eq(short.layers().length(), 1)
  assert_true(short.features().modeled.contains("two-knurl-bands"))

  let long = match @fasteners.heat_set_insert_m3("long") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (_lx0, _lx1, _ly0, _ly1, _lz0, lz1) = long.bounding_box()
  assert_true(hardware_close(lz1, 10.5))
  assert_true(@fasteners.heat_set_insert_m3("medium") is Err(_))
}

///|
test "heat-set insert rejects invalid radial order" {
  let bad : @fasteners.HeatSetInsertSpec = @fasteners.HeatSetInsertSpec::{
    thread: "M3",
    length_mm: 6.0,
    body_diameter_mm: 6.0,
    knurl_diameter_mm: 5.0,
    bore_diameter_mm: 2.25,
  }
  assert_true(@fasteners.heat_set_insert(bad) is Err(_))
  let bad_bore : @fasteners.HeatSetInsertSpec = @fasteners.HeatSetInsertSpec::{
    thread: "M3",
    length_mm: 6.0,
    body_diameter_mm: 2.0,
    knurl_diameter_mm: 6.48,
    bore_diameter_mm: 2.25,
  }
  assert_true(@fasteners.heat_set_insert(bad_bore) is Err(_))
}
