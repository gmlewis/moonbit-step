///|
/// Deterministic parameter-sweep and property tests.
///
/// The pseudo-random transform sweep uses a fixed linear-congruential seed
/// (`12345678`) so the sequence is reproducible; it is not a statistical test.
/// Every check is a geometric invariant (finite dimensions, symmetry, positive
/// extents, transform round-trip, no unintended frame collision).

//|
fn sweep_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn assert_finite_bbox(
  label : String,
  bbox : (Double, Double, Double, Double, Double, Double),
) -> Unit raise {
  let (x0, x1, y0, y1, z0, z1) = bbox
  for v in [x0, x1, y0, y1, z0, z1] {
    if !(v == v) || v.abs() > 1.0e300 {
      fail("\{label}: non-finite bounding box value \{v}")
    }
  }
  if x1 <= x0 || y1 <= y0 || z1 <= z0 {
    fail("\{label}: non-positive bounding box extents")
  }
}

///|
test "fastener size and length sweep has finite symmetric bboxes" {
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let d = size.nominal_diameter_mm()
    for length in [d * 3.0, d * 5.0, d * 8.0] {
      let screw = match
        @fasteners.iso4762_screw(size, length, detail=@common.Detailed) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
      let bbox = screw.bounding_box()
      assert_finite_bbox("ISO4762 " + size.designation(), bbox)
      let (x0, x1, y0, y1, _z0, z1) = bbox
      // A socket head cap screw is symmetric about both plan axes.
      assert_true(sweep_close(x0, -x1, 1.0e-9))
      assert_true(sweep_close(y0, -y1, 1.0e-9))
      // The head adds material above the nominal length.
      assert_true(z1 > length + 1.0)
      let nut = match @fasteners.iso4032_nut(size, detail=@common.Detailed) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
      assert_finite_bbox("ISO4032 " + size.designation(), nut.bounding_box())
    }
  }
}

///|
test "new head standards accept only their supported size and length ranges" {
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let d = size.nominal_diameter_mm()
    assert_true(
      @fasteners.iso7380_screw(size, d * 4.0, detail=@common.Detailed) is Ok(_),
    )
    assert_true(
      @fasteners.iso10642_screw(size, d * 4.0, detail=@common.Detailed) is Ok(_),
    )
  }
  assert_true(@fasteners.iso7380_screw(@standards.M2, 12.0) is Err(_))
  assert_true(@fasteners.iso10642_screw(@standards.M2, 12.0) is Err(_))
  assert_true(@fasteners.iso7380_screw(@standards.M8, 5.0) is Err(_))
}

///|
test "bearing designation sweep keeps eight analytic balls" {
  for designation in @motion.bearing_designations() {
    let bearing = match
      @motion.bearing_by_designation(designation, detail=@common.Detailed) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_finite_bbox("bearing " + designation, bearing.bounding_box())
    assert_true(bearing.features().has_modeled("ball-sphere"))
    let balls = bearing.layers().filter(fn(l) { l.name.contains("ball-") })
    assert_eq(balls.length(), 8)
  }
}

///|
test "gear module and tooth-count sweep stays simple and positive-area" {
  for module_mm in [1.0, 2.0, 3.0] {
    for teeth in [12, 20, 40] {
      let outline = @gears.external_involute_outline(module_mm, teeth, 20.0)
      assert_true(@cad.Profile2D::is_simple(outline))
      assert_true(@gears.involute_outline_area(outline).abs() > 0.0)
      let params = match
        @gears.SpurGearParams::new(
          module_mm~,
          teeth~,
          face_width_mm=8.0,
          bore_diameter_mm=module_mm * 2.0,
        ) {
        Ok(p) => p
        Err(e) => abort(e.message())
      }
      let gear = match @gears.spur_gear(params) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
      assert_finite_bbox("gear m\{module_mm} z\{teeth}", gear.bounding_box())
    }
  }
}

///|
test "extrusion series sweep is a simple positive-area section" {
  for
    profile in [
      @profiles.TSlotProfile::generic_2020(),
      @profiles.TSlotProfile::generic_2040(),
      @profiles.TSlotProfile::generic_2060(),
      @profiles.TSlotProfile::generic_2080(),
      @profiles.TSlotProfile::generic_3030(),
      @profiles.TSlotProfile::generic_3060(),
      @profiles.TSlotProfile::generic_4040(),
      @profiles.TSlotProfile::generic_4080(),
    ] {
    let outline = profile.outline()
    assert_true(@cad.Profile2D::is_simple(outline))
    let part = match @profiles.extrusion(profile, 100.0) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
    assert_finite_bbox(profile.name, part.bounding_box())
  }
}

///|
test "frame dimension sweep keeps the outside dimensions and no OBB collisions" {
  for (w, d, h) in [(200.0, 200.0, 200.0), (400.0, 300.0, 500.0)] {
    let frame = match
      @assemblies.extrusion_frame(
        w,
        d,
        h,
        @profiles.TSlotProfile::generic_2020(),
      ) {
      Ok(a) => a
      Err(e) => abort(e.message())
    }
    let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
    assert_true(sweep_close(x1 - x0, w, 1.0e-6))
    assert_true(sweep_close(y1 - y0, d, 1.0e-6))
    assert_true(sweep_close(z1 - z0, h, 1.0e-6))
    // Rails are cut to the clear span, so no member overlaps another.
    assert_true(frame.collisions().is_empty())
    assert_true(frame.is_connected())
  }
}

///|
test "seeded rigid transforms round-trip and compose" {
  // Fixed seed 12345678; Numerical Recipes LCG constants, modulus 2^31-1.
  let mut state : Int64 = 12345678L
  let modulus : Int64 = 2147483647L
  let sample = fn() -> Double {
    state = (state * 1664525L + 1013904223L) % modulus
    (state.to_double() / modulus.to_double() - 0.5) * 100.0
  }
  for _i in 0..<20 {
    let placement = @common.Placement::at(
      sample(),
      sample(),
      sample(),
      rx=sample(),
      ry=sample(),
      rz=sample(),
    )
    let p = (3.0, -4.0, 5.0)
    let round_trip = placement.inverse().apply_point(placement.apply_point(p))
    assert_true(sweep_close(round_trip.0, p.0, 1.0e-9))
    assert_true(sweep_close(round_trip.1, p.1, 1.0e-9))
    assert_true(sweep_close(round_trip.2, p.2, 1.0e-9))
    let inner = @common.Placement::translation(1.0, 2.0, 3.0)
    let composed = @common.Placement::compose(placement, inner)
    let direct = placement.apply_point(inner.apply_point(p))
    let chained = composed.apply_point(p)
    assert_true(sweep_close(chained.0, direct.0, 1.0e-9))
    assert_true(sweep_close(chained.1, direct.1, 1.0e-9))
    assert_true(sweep_close(chained.2, direct.2, 1.0e-9))
  }
}
