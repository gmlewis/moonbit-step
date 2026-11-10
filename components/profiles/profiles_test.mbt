///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "generic 2020 section outline" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let outline = profile.outline()
  assert_true(outline.length() > 32)
  let holes = profile.holes()
  assert_eq(holes.length(), 1)
  let mut min_x = 1.0e300
  let mut max_x = -1.0e300
  for (x, _y) in outline {
    if x < min_x {
      min_x = x
    }
    if x > max_x {
      max_x = x
    }
  }
  assert_true(close(min_x, -10.0))
  assert_true(close(max_x, 10.0))
}

///|
test "custom profile validation" {
  assert_true(
    @profiles.TSlotProfile::custom(
      name="bad",
      width_mm=20.0,
      height_mm=20.0,
      slot_width_mm=6.0,
      slot_neck_depth_mm=2.5,
      slot_depth_mm=6.0,
      cavity_width_mm=5.0,
      core_bore_diameter_mm=4.2,
      wall_mm=1.8,
    )
    is Err(_),
  )
  assert_true(
    @profiles.TSlotProfile::custom(
      name="good",
      width_mm=20.0,
      height_mm=20.0,
      slot_width_mm=6.0,
      slot_neck_depth_mm=2.5,
      slot_depth_mm=6.0,
      cavity_width_mm=11.0,
      core_bore_diameter_mm=4.2,
      wall_mm=1.8,
    )
    is Ok(_),
  )
}

///|
test "extrusion cut length and bounds" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let part = match @profiles.extrusion(profile, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -10.0))
  assert_true(close(x1, 10.0))
  assert_true(close(y0, -10.0))
  assert_true(close(y1, 10.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 100.0))
  assert_eq(part.layers().length(), 1)
}

///|
test "extrusion rejects invalid lengths" {
  let profile = @profiles.TSlotProfile::generic_2020()
  assert_true(@profiles.extrusion(profile, 0.0) is Err(_))
  assert_true(@profiles.extrusion(profile, -5.0) is Err(_))
}
