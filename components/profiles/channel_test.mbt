///|
fn channel_has(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn channel_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
fn channel_volume(part : @common.Component) -> Double {
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  volume
}

///|
test "P1000-style channel has the published boundary and hole pattern" {
  let section = @profiles.ChannelSection::p1000()
  assert_true((section.material_area() - 344.76).abs() < 1.0e-9)
  let holes = section.hole_positions(100.0)
  assert_true(holes.length() == 2)
  assert_true((holes[0] - 23.8).abs() < 1.0e-9)
  assert_true((holes[1] - 71.4).abs() < 1.0e-9)
  let part = match @profiles.strut_channel(section, 100.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 41.3).abs() < 1.0e-6)
  assert_true((y1 - y0 - 41.3).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 100.0).abs() < 1.0e-6)
  assert_true(part.layers().length() == 3)
  assert_true((channel_volume(part) - 33640.848).abs() < 1.0)
  for
    name in [
      "slot-open", "back-face", "end-a", "end-b", "centerline", "hole-1", "hole-2",
    ] {
    if !channel_has(part, name) {
      abort("strut channel is missing connector " + name)
    }
  }
  let hole = channel_connector(part, "hole-1")
  assert_true((hole.placement.trans.1 + 20.65).abs() < 1.0e-9)
  assert_true((hole.placement.trans.2 - 23.8).abs() < 1.0e-9)
  assert_true(hole.axis.1 > 0.99)
  match hole.diameter_mm {
    Some(d) => assert_true((d - 14.3).abs() < 1.0e-9)
    None => fail("expected the channel hole diameter")
  }
}

///|
test "unpunched strut channel is one C extrusion" {
  let result = @profiles.strut_channel(
    @profiles.ChannelSection::p1000(),
    100.0,
    punched=false,
  )
  let part = match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(part.layers().length() == 1)
  assert_true((channel_volume(part) - 34476.0).abs() < 1.0)
  assert_true(channel_has(part, "slot-open"))
  assert_true(!channel_has(part, "hole-1"))
}

///|
test "strut channel rejects short cuts and impossible sections" {
  assert_true(
    @profiles.strut_channel(@profiles.ChannelSection::p1000(), 20.0) is Err(_),
  )
  assert_true(
    @profiles.ChannelSection::custom(
      name="bad",
      width_mm=41.3,
      height_mm=41.3,
      thickness_mm=2.6,
      slot_width_mm=40.0,
      hole_diameter_mm=14.3,
      hole_pitch_mm=47.6,
      hole_start_mm=23.8,
    )
    is Err(_),
  )
}

///|
test "channel nut fits the opening and bears on the lips" {
  let section = @profiles.ChannelSection::p1000()
  let part = match @profiles.channel_nut(section, 5.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 20.0).abs() < 1.0e-6)
  assert_true((y1 - y0 - 6.0).abs() < 1.0e-6)
  assert_true((z1 - z0 - 30.0).abs() < 1.0e-6)
  assert_true((channel_volume(part) - 3482.19).abs() < 0.2)
  for name in ["thread", "face-front", "face-back"] {
    if !channel_has(part, name) {
      abort("channel nut is missing connector " + name)
    }
  }
  let thread = channel_connector(part, "thread")
  match thread.diameter_mm {
    Some(d) => assert_true((d - 5.0).abs() < 1.0e-9)
    None => fail("expected the channel nut thread diameter")
  }
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.axis.1 < -0.99)
}

///|
test "channel nut rejects a nut that cannot enter the opening" {
  let section = @profiles.ChannelSection::p1000()
  assert_true(@profiles.channel_nut(section, 5.0, nut_width_mm=22.2) is Err(_))
  assert_true(@profiles.channel_nut(section, 5.0, nut_length_mm=20.0) is Err(_))
  assert_true(
    @profiles.channel_nut(section, 5.0, nut_thickness_mm=40.0) is Err(_),
  )
}
