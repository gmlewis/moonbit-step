///|
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn unwrap4762_size(s : @standards.MetricSize) -> @standards.ISO4762Size {
  match @standards.iso4762_size(s) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
fn unwrap4762_spec(
  s : @standards.MetricSize,
  l : Double,
) -> @standards.ISO4762Spec {
  match @standards.iso4762_spec(s, l) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
fn unwrap4032_size(s : @standards.MetricSize) -> @standards.ISO4032Size {
  match @standards.iso4032_size(s) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
fn unwrap4032_spec(s : @standards.MetricSize) -> @standards.ISO4032Spec {
  match @standards.iso4032_spec(s) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
fn unwrap7089_size(s : @standards.MetricSize) -> @standards.ISO7089Size {
  match @standards.iso7089_size(s) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}

///|
test "metric size table" {
  assert_eq(@standards.MetricSize::all().length(), 11)
  assert_true(@standards.MetricSize::M4.nominal_diameter_mm() == 4.0)
  assert_true(@standards.MetricSize::M4.coarse_pitch_mm() == 0.7)
  assert_true(@standards.MetricSize::M5.coarse_pitch_mm() == 0.8)
  assert_true(@standards.MetricSize::M3.designation() == "M3")
  assert_true(@standards.MetricSize::from_diameter(5.0) is Some(@standards.M5))
  assert_true(@standards.MetricSize::from_diameter(5.1) is None)
  assert_true(@standards.MetricSize::parse("M4") is Some(@standards.M4))
  assert_true(@standards.MetricSize::parse("m3") is Some(@standards.M3))
  assert_true(@standards.MetricSize::parse("M7") is None)
}

///|
test "iso 68-1 derived thread diameters" {
  let thread = @standards.ThreadSpec::coarse(@standards.M4)
  let h = thread.height_h_mm()
  assert_true(close(h, 0.606217782649107))
  assert_true(close(thread.pitch_diameter_mm(), 4.0 - 0.75 * h))
  assert_true(close(thread.external_minor_diameter_mm(), 4.0 - 17.0 / 12.0 * h))
  assert_true(close(thread.internal_minor_diameter_mm(), 4.0 - 1.25 * h))
  assert_true(close(thread.external_thread_depth_mm(), 17.0 / 24.0 * h))
  assert_true(close(thread.internal_thread_depth_mm(), 5.0 / 8.0 * h))
  assert_true(thread.pitch_diameter_mm() < 4.0)
  assert_true(
    thread.external_minor_diameter_mm() < thread.internal_minor_diameter_mm(),
  )
  // The basic profile must be self-consistent: diameter = 2 * depth below the
  // major diameter. The previous constants (0.61343 vs 1.226869) disagreed.
  for size in @standards.MetricSize::all() {
    let t = @standards.ThreadSpec::coarse(size)
    let d = size.nominal_diameter_mm()
    assert_true(
      close(
        t.external_minor_diameter_mm() + 2.0 * t.external_thread_depth_mm(),
        d,
      ),
    )
    assert_true(
      close(
        t.internal_minor_diameter_mm() + 2.0 * t.internal_thread_depth_mm(),
        d,
      ),
    )
  }
}

///|
test "thread ridge profile is the ISO 68-1 60-degree basic profile" {
  // The flank makes 30 degrees with the radial direction, so
  // (root_width - crest_width) / 2 / depth = tan(30 degrees).
  let tan30 = 0.5773502691896258
  for size in @standards.MetricSize::all() {
    let t = @standards.ThreadSpec::coarse(size)
    let p = t.pitch_mm
    assert_true(close(t.external_thread_crest_width_mm(), p / 8.0))
    assert_true(close(t.external_thread_root_width_mm(), 5.0 * p / 6.0))
    assert_true(close(t.internal_thread_crest_width_mm(), p / 4.0))
    assert_true(close(t.internal_thread_root_width_mm(), 7.0 * p / 8.0))
    let external_delta = (
        t.external_thread_root_width_mm() - t.external_thread_crest_width_mm()
      ) /
      2.0
    assert_true(close(external_delta / t.external_thread_depth_mm(), tan30))
    let internal_delta = (
        t.internal_thread_root_width_mm() - t.internal_thread_crest_width_mm()
      ) /
      2.0
    assert_true(close(internal_delta / t.internal_thread_depth_mm(), tan30))
  }
}

///|
test "custom thread rejects an impossible pitch" {
  assert_true(@standards.ThreadSpec::custom(@standards.M4, 0.5) is Ok(_))
  assert_true(@standards.ThreadSpec::custom(@standards.M4, 0.0) is Err(_))
  assert_true(@standards.ThreadSpec::custom(@standards.M4, 4.0) is Err(_))
}

///|
test "iso 4762 known dimensions for m3 m4 m5" {
  let m3 = unwrap4762_size(@standards.M3)
  assert_true(close(m3.head_diameter_mm, 5.5))
  assert_true(close(m3.head_height_mm, 3.0))
  assert_true(close(m3.socket_across_flats_mm, 2.5))
  assert_true(close(m3.socket_depth_mm, 1.3))
  let m4 = unwrap4762_size(@standards.M4)
  assert_true(close(m4.head_diameter_mm, 7.0))
  assert_true(close(m4.head_height_mm, 4.0))
  assert_true(close(m4.socket_across_flats_mm, 3.0))
  let m5 = unwrap4762_size(@standards.M5)
  assert_true(close(m5.head_diameter_mm, 8.5))
  assert_true(close(m5.head_height_mm, 5.0))
  assert_true(close(m5.socket_across_flats_mm, 4.0))
}

///|
test "iso 4762 length and thread engagement" {
  let short = unwrap4762_spec(@standards.M4, 10.0)
  assert_true(short.fully_threaded)
  assert_true(close(short.thread_length_mm, 10.0))
  let long = unwrap4762_spec(@standards.M4, 20.0)
  assert_true(!long.fully_threaded)
  assert_true(close(long.thread_length_mm, 14.0))
  assert_true(long.designation() == "ISO 4762 - M4 x 20")
}

///|
test "iso 4762 rejects unsupported lengths" {
  assert_true(@standards.iso4762_spec(@standards.M4, 5.0) is Err(_))
  assert_true(@standards.iso4762_spec(@standards.M4, 81.0) is Err(_))
  assert_true(@standards.iso4762_spec(@standards.M4, 0.0) is Err(_))
  assert_true(@standards.iso4762_spec(@standards.M4, 20.0) is Ok(_))
}

///|
test "iso 4032 known dimensions" {
  let m3 = unwrap4032_size(@standards.M3)
  assert_true(close(m3.width_across_flats_mm, 5.5))
  assert_true(close(m3.height_mm, 2.4))
  let m4 = unwrap4032_size(@standards.M4)
  assert_true(close(m4.width_across_flats_mm, 7.0))
  assert_true(close(m4.height_mm, 3.2))
  let m5 = unwrap4032_size(@standards.M5)
  assert_true(close(m5.width_across_flats_mm, 8.0))
  // ISO 4032:2023 M5 height (DIN 934 used 4.0).
  assert_true(close(m5.height_mm, 4.7))
  let spec = unwrap4032_spec(@standards.M4)
  assert_true(spec.designation() == "ISO 4032 - M4")
}

///|
test "iso 4032 rejects negative clearance" {
  assert_true(
    @standards.iso4032_spec(@standards.M4, clearance_mm=-0.1) is Err(_),
  )
  assert_true(@standards.iso4032_spec(@standards.M4, clearance_mm=0.2) is Ok(_))
}

///|
test "iso 7089 known washer dimensions" {
  let m3 = unwrap7089_size(@standards.M3)
  assert_true(close(m3.inner_diameter_mm, 3.2))
  assert_true(close(m3.outer_diameter_mm, 7.0))
  assert_true(close(m3.thickness_mm, 0.5))
  let m4 = unwrap7089_size(@standards.M4)
  assert_true(close(m4.inner_diameter_mm, 4.3))
  assert_true(close(m4.outer_diameter_mm, 9.0))
  assert_true(close(m4.thickness_mm, 0.8))
  let m5 = unwrap7089_size(@standards.M5)
  assert_true(close(m5.inner_diameter_mm, 5.3))
  assert_true(close(m5.outer_diameter_mm, 10.0))
  assert_true(close(m5.thickness_mm, 1.0))
}

///|
test "din 125 a known washer dimensions" {
  let m3 = match @standards.din125_size(@standards.M3) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m3.inner_diameter_mm, 3.2))
  assert_true(close(m3.outer_diameter_mm, 7.0))
  assert_true(close(m3.thickness_mm, 0.5))
  let spec = match @standards.din125_spec(@standards.M3) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(spec.designation() == "DIN 125 A - M3")
  assert_true(@standards.DIN125Spec::standard() == "DIN 125 A")
  assert_true(spec.metadata().standard == "DIN 125 A")
  assert_true(
    spec.metadata().family == "plain washer, normal series (DIN 125 A)",
  )
  // DIN 125 A / ISO 7089 M8: h nominal 1.6 mm, limits 1.4..1.8 mm. The
  // reference thickness is the upper limit, matching the downloaded reference.
  let m8 = match @standards.din125_size(@standards.M8) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m8.inner_diameter_mm, 8.4))
  assert_true(close(m8.outer_diameter_mm, 16.0))
  assert_true(close(m8.thickness_mm, 1.8))
}

///|
test "din 127 b known spring washer dimensions" {
  let m4 = match @standards.din127_size(@standards.M4) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m4.inner_diameter_mm, 4.1))
  assert_true(close(m4.outer_diameter_mm, 7.6))
  assert_true(close(m4.side_width_mm, 1.5))
  assert_true(close(m4.thickness_mm, 0.9))
  assert_true(close(m4.free_height_mm, 1.8))
  let spec = match @standards.din127_spec(@standards.M4) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(spec.designation() == "DIN 127 B - M4")
  assert_true(@standards.DIN127Spec::standard() == "DIN 127 B")
  assert_true(spec.metadata().family == "spring washer, form B")
  // The downloaded M6 reference uses d1 = 6.1 mm (some tables print 6.4).
  let m6 = match @standards.din127_size(@standards.M6) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m6.inner_diameter_mm, 6.1))
  assert_true(close(m6.outer_diameter_mm, 11.8))
  assert_true(close(m6.thickness_mm, 1.6))
  assert_true(close(m6.free_height_mm, 3.2))
}

///|
test "din 440 v large washer dimensions" {
  let m5 = match @standards.din440_size(@standards.M5) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m5.outer_diameter_mm, 18.0))
  assert_true(close(m5.square_side_mm, 5.5))
  assert_true(close(m5.thickness_mm, 2.0))
  let spec = match @standards.din440_spec(@standards.M5) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(spec.designation() == "DIN 440 V - M5")
  assert_true(@standards.DIN440Spec::standard() == "DIN 440 V")
  assert_true(
    spec.metadata().family == "large washer, square hole (timber construction)",
  )
  let m8 = match @standards.din440_size(@standards.M8) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m8.outer_diameter_mm, 28.0))
  assert_true(close(m8.square_side_mm, 9.0))
  assert_true(close(m8.thickness_mm, 3.0))
}

///|
test "din 7349 thick washer dimensions" {
  let m3 = match @standards.din7349_size(@standards.M3) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m3.inner_diameter_mm, 3.2))
  assert_true(close(m3.outer_diameter_mm, 9.0))
  assert_true(close(m3.thickness_mm, 1.0))
  let spec = match @standards.din7349_spec(@standards.M3) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(spec.designation() == "DIN 7349 - M3")
  assert_true(@standards.DIN7349Spec::standard() == "DIN 7349")
  assert_true(spec.metadata().family == "thick flat washer, heavy pattern")
  let m8 = match @standards.din7349_size(@standards.M8) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m8.inner_diameter_mm, 8.4))
  assert_true(close(m8.outer_diameter_mm, 21.0))
  assert_true(close(m8.thickness_mm, 4.0))
}

///|
test "din 913 set screw dimensions" {
  let m3 = match @standards.din913_size(@standards.M3) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(m3.socket_across_flats_mm, 1.5))
  assert_true(close(m3.socket_across_flats_max_mm, 1.545))
  assert_true(close(m3.socket_depth_mm, 2.0))
  // The downloaded M3 reference uses a 2.2 mm flat; the DIN d_p max is 2.0.
  assert_true(close(m3.point_flat_diameter_mm, 2.2))
  assert_true(close(m3.point_angle_deg, 90.0))
  let spec = match @standards.din913_spec(@standards.M3, 5.0) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(spec.designation() == "DIN 913 - M3 x 5")
  assert_true(@standards.DIN913Spec::standard() == "DIN 913")
  assert_true(
    spec.metadata().family == "hexagon socket set screw with flat point",
  )
  assert_true(@standards.din913_size(@standards.M4) is Err(_))
}

///|
test "iso 4017 and iso 4014 hex head dimensions" {
  let h4 = match @standards.hex_head_size(@standards.M4) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(close(h4.width_across_flats_mm, 7.0))
  assert_true(close(h4.head_height_mm, 2.8))
  let full = match @standards.iso4017_spec(@standards.M4, 20.0) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(full.designation() == "ISO 4017 - M4 x 20")
  let partial = match @standards.iso4014_spec(@standards.M8, 80.0) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(!partial.fully_threaded)
  assert_true(close(partial.thread_length_mm, 22.0))
  assert_true(@standards.iso4014_spec(@standards.M4, 4.0) is Err(_))
}

///|
test "din 976 threaded rod validation" {
  let rod = match @standards.din976_spec(@standards.M8, 1000.0) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(rod.designation() == "DIN 976-1 - M8 x 1000")
  assert_true(@standards.din976_spec(@standards.M8, 5.0) is Err(_))
  assert_true(@standards.din976_spec(@standards.M8, 1000.0) is Ok(_))
}
