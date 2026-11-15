///|
fn tm_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn tm_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "measured tire mount envelope matches the owner-authored model" {
  let spec = @motion.tire_mount_spec()
  assert_true(@motion.tire_mount_spec_valid(spec) is Ok(_))
  let mount = tm_ok(@motion.measured_tire_mount())
  let (x0, x1, y0, y1, z0, z1) = mount.bounding_box()
  assert_true(tm_close(x0, -28.05))
  assert_true(tm_close(x1, -5.0))
  assert_true(tm_close(y0, -43.15))
  assert_true(tm_close(y1, 43.15))
  assert_true(tm_close(z0, -43.15))
  assert_true(tm_close(z1, 43.15))
  assert_eq(mount.layers().length(), 1)
  assert_true(mount.features().modeled.contains("radial-slots"))
  assert_true(mount.features().modeled.contains("bolt-holes"))
}

///|
test "tire mount hub-post mate sits on the post tip for one-step snapping" {
  let mount = tm_ok(@motion.measured_tire_mount())
  let post = match mount.connector("hub-post") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  // The mate must sit on the post tip (front_offset - plate_thickness), so a
  // plain snap of the tire's hub-bore mate yields the fully seated pose.
  assert_true(tm_close(post.placement.trans.0, -9.0))
  assert_true(tm_close(post.axis.0, 1.0))
}

///|
test "tire mount connectors sit on the external front face" {
  let mount = tm_ok(@motion.measured_tire_mount())
  for name in ["hub-post", "front-face", "rear-face"] {
    assert_true(mount.connector(name) is Ok(_))
  }
  for i in 1..<=3 {
    assert_true(mount.connector("bolt-hole-\{i}") is Ok(_))
  }
  let front = match mount.connector("front-face") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(tm_close(front.placement.trans.0, -5.0))
  assert_true(front.axis.0 < 0.0)
  let hole = match mount.connector("bolt-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(tm_close(hole.placement.trans.0, -5.0))
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
}

///|
test "tire mount parameters can be overridden for a measured flange" {
  let spec : @motion.TireMountSpec = {
    ..@motion.tire_mount_spec(),
    outer_diameter_mm: 70.0,
    front_inner_diameter_mm: 40.0,
    hub_outer_diameter_mm: 20.0,
    hub_bore_diameter_mm: 10.0,
    plate_thickness_mm: 3.0,
    ring_depth_mm: 15.0,
    slot_width_mm: 1.5,
    slot_count: 5,
    bolt_hole_count: 4,
    bolt_hole_diameter_mm: 3.0,
    bolt_hole_circle_diameter_mm: 56.0,
    bolt_hole_phase_deg: 45.0,
  }
  assert_true(@motion.tire_mount_spec_valid(spec) is Ok(_))
  let mount = tm_ok(@motion.tire_mount(spec))
  let (x0, x1, y0, y1, _z0, _z1) = mount.bounding_box()
  assert_true(tm_close(x0, -23.0))
  assert_true(tm_close(x1, -5.0))
  assert_true(tm_close(y0, -35.0))
  assert_true(tm_close(y1, 35.0))
  for i in 1..<=4 {
    assert_true(mount.connector("bolt-hole-\{i}") is Ok(_))
  }
}

///|
test "tire mount validation rejects inconsistent envelopes" {
  let bad_inner : @motion.TireMountSpec = {
    ..@motion.tire_mount_spec(),
    front_inner_diameter_mm: 86.3,
  }
  assert_true(@motion.tire_mount_spec_valid(bad_inner) is Err(_))
  let bad_bore : @motion.TireMountSpec = {
    ..@motion.tire_mount_spec(),
    hub_bore_diameter_mm: 30.0,
  }
  assert_true(@motion.tire_mount_spec_valid(bad_bore) is Err(_))
  let bad_slots : @motion.TireMountSpec = {
    ..@motion.tire_mount_spec(),
    slot_count: 2,
  }
  assert_true(@motion.tire_mount_spec_valid(bad_slots) is Err(_))
}
