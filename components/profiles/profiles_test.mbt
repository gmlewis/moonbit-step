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

//|

///|
fn section_orient(a : @cad.Vec2, b : @cad.Vec2, c : @cad.Vec2) -> Double {
  (b.0 - a.0) * (c.1 - a.1) - (b.1 - a.1) * (c.0 - a.0)
}

//|

///|
fn section_crosses(
  a0 : @cad.Vec2,
  a1 : @cad.Vec2,
  b0 : @cad.Vec2,
  b1 : @cad.Vec2,
) -> Bool {
  let o1 = section_orient(a0, a1, b0)
  let o2 = section_orient(a0, a1, b1)
  let o3 = section_orient(b0, b1, a0)
  let o4 = section_orient(b0, b1, a1)
  o1 * o2 < -1.0e-9 && o3 * o4 < -1.0e-9
}

//|

///|
fn section_area(points : Array[@cad.Vec2]) -> Double {
  let mut sum = 0.0
  let n = points.length()
  for i in 0..<n {
    let a = points[i]
    let b = points[(i + 1) % n]
    sum = sum + a.0 * b.1 - b.0 * a.1
  }
  (sum / 2.0).abs()
}

///|
test "T-slot section outlines are simple polygons with corner arrows" {
  let profiles = [
    @profiles.TSlotProfile::generic_2020(),
    @profiles.TSlotProfile::generic_2040(),
    @profiles.TSlotProfile::generic_3030(),
    @profiles.TSlotProfile::generic_4040(),
  ]
  for profile in profiles {
    let points = profile.outline()
    let n = points.length()
    assert_true(n >= 36)
    let mut crossings = 0
    for i in 0..<n {
      let a0 = points[i]
      let a1 = points[(i + 1) % n]
      for j in (i + 1)..<n {
        // Adjacent edges share a vertex by construction.
        if j == (i + 1) % n || i == (j + 1) % n {
          continue
        }
        let b0 = points[j]
        let b1 = points[(j + 1) % n]
        if section_crosses(a0, a1, b0, b1) {
          crossings = crossings + 1
        }
      }
    }
    if crossings > 0 {
      abort(
        "profile " +
        profile.name +
        " outline has " +
        crossings.to_string() +
        " self-intersections",
      )
    }
    assert_eq(crossings, 0)
    assert_true(section_area(points) > 0.0)
  }
}

///|
test "generic 2020 outer section area includes four corner arrows" {
  let outline = @profiles.TSlotProfile::generic_2020().outline()
  // 400 mm^2 square minus four tapered T-slot notches (48.46 mm^2 each).
  assert_true((section_area(outline) - 206.16).abs() < 1.0e-6)
}
