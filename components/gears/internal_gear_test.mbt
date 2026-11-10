///|
/// Exact internal involute ring gear tests.

//|
fn ring_radius_range(outline : Array[@cad.Vec2]) -> (Double, Double) {
  let mut min_r = 1.0e300
  let mut max_r = 0.0
  for (x, y) in outline {
    let r = Double::sqrt(x * x + y * y)
    if r < min_r {
      min_r = r
    }
    if r > max_r {
      max_r = r
    }
  }
  (min_r, max_r)
}

//|

///|
test "internal involute ring geometry has an inward tip and outward root" {
  let geom = @gears.internal_ring_geometry(2.0, 36, 20.0)
  // pitch = m*z/2 = 36; base = 36 cos 20 = 33.8296
  assert_true((geom.pitch_radius_mm - 36.0).abs() < 1.0e-9)
  assert_true((geom.base_radius_mm - 36.0 * 0.9396926207859084).abs() < 1.0e-6)
  // tip = pitch - m = 34 (inward); root = pitch + 1.25 m = 38.5 (outward).
  assert_true((geom.tip_radius_mm - 34.0).abs() < 1.0e-9)
  assert_true((geom.root_radius_mm - 38.5).abs() < 1.0e-9)
  assert_true(geom.tip_radius_mm > geom.base_radius_mm)
}

///|
test "internal involute ring profile is a simple closed bore boundary" {
  let outline = match
    @gears.internal_involute_ring_profile(2.0, 36, 20.0, backlash_mm=0.1) {
    Ok(o) => o
    Err(e) => abort(e.message())
  }
  assert_true(@cad.Profile2D::is_simple(outline))
  assert_true(outline.length() > 36 * 20)
  // The bore boundary is wound counter-clockwise, so its signed area is
  // positive and close to the full disc minus the ring teeth.
  assert_true(@cad.polygon_area_2d(outline) > 0.0)
  let (min_r, max_r) = ring_radius_range(outline)
  let geom = @gears.internal_ring_geometry(2.0, 36, 20.0)
  assert_true((min_r - geom.tip_radius_mm).abs() < 1.0e-6)
  assert_true((max_r - geom.root_radius_mm).abs() < 1.0e-6)
}

///|
test "internal ring rejects a tip at or below the base circle" {
  // N = 20: tip = m*N/2 - m = 18, base = 20 cos 20 = 18.79, so the involute
  // would be truncated; the builder must reject it rather than fabricate a
  // non-involute tip.
  assert_true(@gears.internal_involute_ring_profile(2.0, 20, 20.0) is Err(_))
  assert_true(@gears.internal_ring_gear_exact(2.0, 20, 10.0) is Err(_))
}

///|
test "internal ring parameter validation" {
  assert_true(@gears.internal_involute_ring_profile(0.0, 36, 20.0) is Err(_))
  assert_true(@gears.internal_involute_ring_profile(2.0, 4, 20.0) is Err(_))
  assert_true(@gears.internal_involute_ring_profile(2.0, 36, 50.0) is Err(_))
  assert_true(
    @gears.internal_involute_ring_profile(2.0, 36, 20.0, backlash_mm=-1.0)
    is Err(_),
  )
}

///|
test "internal mesh clears a full rotation cycle with declared backlash" {
  // z_p = 12 is the low-tooth-count case that grazes the ring tip without
  // backlash. 0.05 * module is the documented engineering default.
  let m = 2.0
  let cases = [(36, 12), (42, 12), (48, 12), (48, 18), (60, 20)]
  for (ring_teeth, planet_teeth) in cases {
    let crossings = match
      @gears.internal_mesh_interference(
        m,
        ring_teeth,
        planet_teeth,
        20.0,
        backlash_mm=0.05 * m,
        phases=32,
      ) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    if crossings != 0 {
      abort(
        "internal mesh z\{ring_teeth}/z\{planet_teeth} has " +
        crossings.to_string() +
        " crossings",
      )
    }
    assert_eq(crossings, 0)
  }
}

///|
test "the internal mesh check is sensitive to a missing backlash" {
  // A zero-backlash z36/z12 mesh grazes at the ring tip; the check must report
  // crossings, proving the passing case above is not vacuous.
  let crossings = match
    @gears.internal_mesh_interference(2.0, 36, 12, 20.0, backlash_mm=0.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(crossings > 0)
}

///|
test "internal mesh is scale invariant" {
  for m in [1.0, 3.0] {
    let crossings = match
      @gears.internal_mesh_interference(
        m,
        36,
        12,
        20.0,
        backlash_mm=0.05 * m,
        phases=24,
      ) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_eq(crossings, 0)
  }
}

///|
test "internal ring and mesh pass a module and tooth-count sweep" {
  for module_mm in [1.0, 2.0, 3.0] {
    for ring_teeth in [36, 42, 48] {
      let profile = match
        @gears.internal_involute_ring_profile(
          module_mm,
          ring_teeth,
          20.0,
          backlash_mm=0.05 * module_mm,
        ) {
        Ok(p) => p
        Err(e) => abort(e.message())
      }
      assert_true(@cad.Profile2D::is_simple(profile))
      let geom = @gears.internal_ring_geometry(module_mm, ring_teeth, 20.0)
      let (min_r, max_r) = ring_radius_range(profile)
      assert_true((min_r - geom.tip_radius_mm).abs() < 1.0e-6)
      assert_true((max_r - geom.root_radius_mm).abs() < 1.0e-6)
      let crossings = match
        @gears.internal_mesh_interference(
          module_mm,
          ring_teeth,
          12,
          20.0,
          backlash_mm=0.05 * module_mm,
          phases=24,
        ) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
      assert_eq(crossings, 0)
    }
  }
}

///|
test "exact internal ring gear builds and records the involute envelope" {
  let ring = match
    @gears.internal_ring_gear_exact(2.0, 36, 10.0, backlash_mm=0.1) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let features = ring.features()
  assert_true(features.has_modeled("internal-involute-tooth-envelope"))
  assert_true(features.has_approximated("internal-involute-flank"))
  assert_true(!features.has_modeled("exact-involute-internal-envelope"))
  let geom = @gears.internal_ring_geometry(2.0, 36, 20.0)
  let outer = geom.root_radius_mm + 5.0
  let (x0, x1, y0, y1, z0, z1) = ring.bounding_box()
  assert_true(x1 <= outer + 1.0e-6 && x0 >= -outer - 1.0e-6)
  assert_true(y1 <= outer + 1.0e-6 && y0 >= -outer - 1.0e-6)
  assert_true(z0.abs() < 1.0e-9 && (z1 - 10.0).abs() < 1.0e-9)
  let step = ring.to_step(checked=true)
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
  assert_true(step.contains("CLOSED_SHELL"))
}

///|
test "planetary set uses the exact ring and meshes statically" {
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=12,
      planet_teeth=12,
      planet_count=3,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true((params.internal_mesh_backlash() - 0.1).abs() < 1.0e-12)
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let backlash = params.internal_mesh_backlash()
  let planet = @gears.external_involute_outline(
    2.0,
    12,
    20.0,
    backlash_mm=backlash,
  )
  let ring = match
    @gears.internal_involute_ring_profile(2.0, 36, 20.0, backlash_mm=backlash) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let mut total = 0
  for item in set.items() {
    if item.instance_name.has_prefix("ring") {
      // The ring must carry the exact-envelope feature record.
      assert_true(
        item.component
        .features()
        .has_modeled("internal-involute-tooth-envelope"),
      )
    }
  }
  // Static planet/ring outline crossings, using the same placements the
  // assembly chose. The ring is at rotation 0 with a tooth on +X.
  for item in set.items() {
    if item.instance_name.has_prefix("planet-") {
      let world = planet.map(fn(p) {
        let q = item.placement.apply_point((p.0, p.1, 0.0))
        (q.0, q.1)
      })
      total = total + static_outline_crossings(ring, world)
    }
  }
  if total > 0 {
    abort("planetary planet/ring static crossings: " + total.to_string())
  }
  assert_eq(total, 0)
}

//|

///|
fn static_outline_crossings(
  a : Array[@cad.Vec2],
  b : Array[@cad.Vec2],
) -> Int32 {
  let mut crossings = 0
  let na = a.length()
  let nb = b.length()
  for i in 0..<na {
    let a0 = a[i]
    let a1 = a[(i + 1) % na]
    for j in 0..<nb {
      let b0 = b[j]
      let b1 = b[(j + 1) % nb]
      if static_segments_cross(a0, a1, b0, b1) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

//|

///|
fn static_segments_cross(
  a0 : @cad.Vec2,
  a1 : @cad.Vec2,
  b0 : @cad.Vec2,
  b1 : @cad.Vec2,
) -> Bool {
  let o1 = (a1.0 - a0.0) * (b0.1 - a0.1) - (a1.1 - a0.1) * (b0.0 - a0.0)
  let o2 = (a1.0 - a0.0) * (b1.1 - a0.1) - (a1.1 - a0.1) * (b1.0 - a0.0)
  let o3 = (b1.0 - b0.0) * (a0.1 - b0.1) - (b1.1 - b0.1) * (a0.0 - b0.0)
  let o4 = (b1.0 - b0.0) * (a1.1 - b0.1) - (b1.1 - b0.1) * (a1.0 - b0.0)
  let eps = 1.0e-12
  o1 * o2 < -eps && o3 * o4 < -eps
}
