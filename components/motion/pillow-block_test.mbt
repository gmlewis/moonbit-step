///|
/// Black-box tests for the UCP-series pillow-block bearing.

///|
fn pb_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-3
}

///|
fn pb_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  match part.connector(name) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn pb_has(part : @common.Component, name : String) -> Bool {
  match part.connector(name) {
    Ok(_) => true
    Err(_) => false
  }
}

///|
test "UCP-series size table" {
  let ucp204 = match @motion.pillow_block_size("ucp204") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_eq(ucp204.designation, "UCP204")
  assert_true(pb_close(ucp204.shaft_bore_mm, 20.0))
  assert_true(pb_close(ucp204.shaft_height_mm, 33.3))
  assert_true(pb_close(ucp204.length_mm, 127.0))
  assert_true(pb_close(ucp204.base_width_mm, 38.0))
  assert_true(pb_close(ucp204.bolt_pitch_mm, 95.0))
  assert_true(pb_close(ucp204.seat_radius_mm, 23.54))
  assert_true(pb_close(ucp204.arch_flank_half_width_mm, 30.7974))
  assert_true(pb_close(ucp204.arch_flank_height_mm, 25.7894))
  assert_true(pb_close(ucp204.arch_skirt_half_width_mm, 38.8882))
  // Insert geometry (UC204).
  assert_true(pb_close(ucp204.insert.outer_race_outer_radius_mm, 23.5))
  assert_true(pb_close(ucp204.insert.outer_race_bore_radius_mm, 17.0))
  assert_true(pb_close(ucp204.insert.inner_race_outer_radius_mm, 15.5))
  assert_true(pb_close(ucp204.insert.inner_race_bore_radius_mm, 10.0))
  assert_true(pb_close(ucp204.insert.inner_race_width_mm, 31.0))
  assert_true(pb_close(ucp204.insert.seal_outer_radius_mm, 16.975))
  assert_true(pb_close(ucp204.insert.grease_neck_radius_mm, 1.5))
  assert_true(pb_close(ucp204.insert.grease_shoulder_z_mm, 3.8))
  assert_true(pb_close(ucp204.insert.grease_barrel_top_mm, 4.9))
  assert_true(pb_close(ucp204.insert.grease_total_height_mm, 5.8))
  assert_eq(ucp204.insert.set_screw_angles_deg.length(), 2)
  let ucp205 = match @motion.pillow_block_size("UCP205") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_eq(ucp205.designation, "UCP205")
  assert_true(pb_close(ucp205.shaft_bore_mm, 25.0))
  assert_true(pb_close(ucp205.shaft_height_mm, 36.5))
  assert_true(pb_close(ucp205.length_mm, 140.0))
  assert_true(pb_close(ucp205.bolt_pitch_mm, 105.0))
  assert_true(pb_close(ucp205.seat_radius_mm, 26.04))
  assert_true(pb_close(ucp205.insert.outer_race_outer_radius_mm, 26.0))
  assert_true(pb_close(ucp205.insert.inner_race_outer_radius_mm, 18.0))
  assert_true(@motion.pillow_block_size("UCP999") is Err(_))
  assert_eq(@motion.pillow_block_designations().length(), 2)
}

///|
test "UCP204 detailed assembly has the measured envelope and interfaces" {
  let size = match @motion.pillow_block_size("UCP204") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.pillow_block_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // Housing (fused base + arch), outer race, inner race, two seals, grease
  // fitting (fused hex + nipple), and two set screws.
  assert_eq(part.layers().length(), 8)
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(pb_close(x0, -63.5))
  assert_true(pb_close(x1, 63.5))
  assert_true(pb_close(y0, -19.0))
  assert_true(pb_close(y1, 19.0))
  assert_true(pb_close(z0, 0.0))
  // Crown + grease fitting (the reference's 70.35 mm overall height).
  assert_true(pb_close(z1, 70.35))
  let bore = pb_connector(part, "shaft-bore")
  assert_true(pb_close(bore.diameter_mm.unwrap(), 20.0))
  assert_true(pb_close(bore.depth_mm.unwrap(), 31.0))
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(bore.gender is @common.MateGender::Female)
  let seat = pb_connector(part, "insert-seat")
  assert_true(pb_close(seat.diameter_mm.unwrap(), 47.08))
  assert_true(seat.fit is @cad.Fit::Free)
  let base = pb_connector(part, "base-face")
  assert_true(pb_close(base.placement.trans.2, 0.0))
  assert_true(base.axis.2 < 0.0)
  let left = pb_connector(part, "mounting-slot-1")
  assert_true(pb_close(left.placement.trans.0, -47.5))
  assert_true(pb_close(left.diameter_mm.unwrap(), 13.0))
  assert_true(pb_has(part, "set-screw-1"))
  assert_true(pb_has(part, "set-screw-2"))
  assert_true(pb_has(part, "grease-port"))
  let port = pb_connector(part, "grease-port")
  // The port sits at the spot-face floor, 0.5 mm below the crown apex.
  assert_true(pb_close(port.placement.trans.2, 64.5))
  let screw = pb_connector(part, "set-screw-1")
  assert_true(screw.kind is @common.MateKind::Threaded)
  for
    name in [
      "housing", "mounting-base", "arch", "insert-seat-bore", "grease-boss-bore",
      "outer-race-spherical-od", "inner-race-extended", "seals", "set-screws", "grease-fitting",
    ] {
    assert_true(part.features().modeled.contains(name))
  }
  assert_true(part.features().omitted.length() >= 3)
}

///|
test "UCP205 detailed assembly matches the measured envelope" {
  let size = match @motion.pillow_block_size("UCP205") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match @motion.pillow_block_bearing(size) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(pb_close(x0, -70.0))
  assert_true(pb_close(x1, 70.0))
  // The extended inner race protrudes to +19.8 mm.
  assert_true(pb_close(y0, -19.0))
  assert_true(pb_close(y1, 19.8))
  assert_true(pb_close(z0, 0.0))
  assert_true(pb_close(z1, 75.35))
  let bore = pb_connector(part, "shaft-bore")
  assert_true(pb_close(bore.diameter_mm.unwrap(), 25.0))
  assert_true(pb_close(bore.depth_mm.unwrap(), 34.1))
  let seat = pb_connector(part, "insert-seat")
  assert_true(pb_close(seat.diameter_mm.unwrap(), 52.08))
  let left = pb_connector(part, "mounting-slot-1")
  assert_true(pb_close(left.placement.trans.0, -52.5))
}

///|
test "UCP204 simplified envelope collapses to two solids" {
  let size = match @motion.pillow_block_size("UCP204") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  let part = match
    @motion.pillow_block_bearing(size, detail=@common.DetailLevel::Simplified) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(part.layers().length(), 2)
  let (_x0, _x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true(pb_close(z1, 65.0))
  assert_true(pb_has(part, "shaft-bore"))
  assert_true(pb_has(part, "insert-seat"))
  assert_true(!pb_has(part, "set-screw-1"))
  assert_true(!pb_has(part, "grease-port"))
  let bore = pb_connector(part, "shaft-bore")
  assert_true(pb_close(bore.depth_mm.unwrap(), 16.0))
}

///|
test "pillow block rejects impossible boundaries" {
  let good = match @motion.pillow_block_size("UCP204") {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  // Bore equal to the insert outside diameter.
  assert_true(
    @motion.pillow_block_bearing({
      ..good,
      shaft_bore_mm: good.insert_outer_diameter_mm,
    })
    is Err(_),
  )
  // Arch as wide as the base.
  assert_true(
    @motion.pillow_block_bearing({ ..good, arch_width_mm: 38.0, }) is Err(_),
  )
  // Shaft axis too high: the seat bore no longer opens into the base.
  assert_true(
    @motion.pillow_block_bearing({ ..good, shaft_height_mm: 50.0, }) is Err(_),
  )
  // Seat as large as the outside of the arch.
  assert_true(
    @motion.pillow_block_bearing({
      ..good,
      seat_radius_mm: good.arch_outer_radius_mm,
    })
    is Err(_),
  )
  // Mounting slots past the base corners.
  assert_true(
    @motion.pillow_block_bearing({ ..good, bolt_pitch_mm: 130.0, }) is Err(_),
  )
  // Insert reaching the bottom relief.
  assert_true(
    @motion.pillow_block_bearing({
      ..good,
      insert_outer_diameter_mm: 60.0,
      seat_radius_mm: 30.0,
    })
    is Err(_),
  )
  // The inner race bore must match the declared shaft bore.
  assert_true(
    @motion.pillow_block_bearing({
      ..good,
      insert: { ..good.insert, inner_race_bore_radius_mm: 9.0, },
    })
    is Err(_),
  )
  // The outer race bore must clear the inner race.
  assert_true(
    @motion.pillow_block_bearing({
      ..good,
      insert: { ..good.insert, outer_race_bore_radius_mm: 15.0, },
    })
    is Err(_),
  )
}
