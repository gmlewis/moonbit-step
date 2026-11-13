///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "B-slot6 2020 extrusion matches the reference section" {
  let part = match @profiles.b_slot6_2020_extrusion(50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -10.0))
  assert_true(close(x1, 10.0))
  assert_true(close(y0, -10.0))
  assert_true(close(y1, 10.0))
  assert_true(close(z0, 0.0))
  assert_true(close(z1, 50.0))
  let layers = part.layers()
  assert_eq(layers.length(), 1)
  let inventory = layers[0].shape.surface_inventory()
  // Six cap/side planes plus one plane per outer line segment, and four outer
  // corner radii plus eight bore arcs as analytic cylinders.
  assert_eq(inventory.plane, 86)
  assert_eq(inventory.cylinder, 12)
  let volume = match layers[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // 174.3364 mm^2 x 50 mm; the step.parts reference measures 8716.82 mm^3.
  assert_true((volume - 8716.82).abs() < 0.01)
  let section = match layers[0].shape.section_at_local(25.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true((section.area_mm2 - 174.3364).abs() < 1.0e-3)
  assert_true((section.perimeter_mm - 182.0957).abs() < 1.0e-2)
  assert_true((section.inner_radius_mm - 2.75).abs() < 1.0e-9)
}

///|
test "B-slot6 2020 extrusion can match the reference axis convention" {
  let part = match
    @profiles.b_slot6_2020_extrusion(50.0, orient_to_reference=true) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(close(x0, -10.0))
  assert_true(close(x1, 10.0))
  assert_true(close(y0, -50.0))
  assert_true(close(y1, 0.0))
  assert_true(close(z0, -10.0))
  assert_true(close(z1, 10.0))
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
    @profiles.TSlotProfile::generic_2060(),
    @profiles.TSlotProfile::generic_2080(),
    @profiles.TSlotProfile::generic_3030(),
    @profiles.TSlotProfile::generic_3060(),
    @profiles.TSlotProfile::generic_4040(),
    @profiles.TSlotProfile::generic_4080(),
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

///|
test "profile corner radius rounds the outer corners and records it" {
  let base = @profiles.TSlotProfile::generic_2020()
  let rounded = match base.with_corner_radius(1.5) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let outline = rounded.outline()
  assert_true(@cad.Profile2D::is_simple(outline))
  let base_area = section_area(base.outline())
  let rounded_area = section_area(outline)
  // Rounding removes r^2 * (1 - pi/4) per corner (~0.483 mm^2 at r = 1.5).
  assert_true(rounded_area < base_area)
  assert_true(rounded_area > base_area - 4.0 * 0.2146 * 1.5 * 1.5 * 1.1)
  let part = match @profiles.extrusion(rounded, 50.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(part.features().has_modeled("corner-radii"))
  assert_true(part.features().has_approximated("corner-radius-arc"))
  assert_true(base.with_corner_radius(6.0) is Err(_))
  assert_true(base.with_corner_radius(-1.0) is Err(_))
}

///|
test "generic 2020 is explicitly not the B-slot6 manufacturer section" {
  let profile = @profiles.TSlotProfile::generic_2020()
  let outer = section_area(profile.outline())
  let bore_radius = profile.core_bore_diameter_mm / 2.0
  // The core bore is the default 48-gon hole loop, not a true circle.
  let bore = 0.5 *
    48.0 *
    bore_radius *
    bore_radius *
    @math.sin(2.0 * @math.PI / 48.0)
  let solid = outer - bore
  // The generic envelope solid area is the documented 192.345108 mm^2.
  assert_true((solid - 192.345108).abs() < 0.01)
  // The step.parts B-slot6 2020 golden measures 8716.82 mm^3 / 50 mm =
  // 174.3364 mm^2. The generic profile is not equivalent and must not claim
  // to be; the discrepancy is larger than 5%.
  let golden_section_area = 174.3364
  assert_true((solid - golden_section_area).abs() > 0.05 * golden_section_area)
}
