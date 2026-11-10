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
  assert_true(close(thread.height_h_mm(), 0.606217782649107))
  assert_true(close(thread.pitch_diameter_mm(), 3.54533666301317))
  assert_true(close(thread.external_minor_diameter_mm(), 3.1411917))
  assert_true(close(thread.internal_minor_diameter_mm(), 3.2422276))
  assert_true(close(thread.external_thread_depth_mm(), 0.429401))
  assert_true(thread.pitch_diameter_mm() < 4.0)
  assert_true(
    thread.external_minor_diameter_mm() < thread.internal_minor_diameter_mm(),
  )
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
  assert_true(close(m5.height_mm, 4.0))
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
