///|
fn motion_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn motion_connector(
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
fn motion_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "plain shaft exposes end frames" {
  let part = match @motion.shaft(10.0, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let a = motion_connector(part, "shaft-a")
  let b = motion_connector(part, "shaft-b")
  assert_true(motion_near(a.placement.trans.2, 0.0))
  assert_true(motion_near(b.placement.trans.2, 40.0))
  assert_true(a.kind is @common.MateKind::CylindricalShaft)
}

///|
test "spacer and bushing expose a bore and outer seat" {
  let part = match @motion.spacer(10.0, 5.0, 12.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "bore"))
  assert_true(motion_has_connector(part, "outer-seat"))
  assert_true(motion_has_connector(part, "face-positive"))
  let bore = motion_connector(part, "bore")
  assert_true(bore.gender is @common.MateGender::Female)
}

///|
test "bearing exposes bore, outer seat, and faces" {
  let size = @motion.bearing_size("608") // 8 x 22 x 7
  let part = match size {
    Ok(s) =>
      match @motion.bearing(s, detail=@common.DetailLevel::Simplified) {
        Ok(c) => c
        Err(e) => abort(e.message())
      }
    Err(e) => abort(e.message())
  }
  let bore = motion_connector(part, "bore")
  match bore.diameter_mm {
    Some(d) => assert_true(motion_near(d, 8.0))
    None => fail("expected bearing bore diameter")
  }
  let seat = motion_connector(part, "outer-seat")
  match seat.diameter_mm {
    Some(d) => assert_true(motion_near(d, 22.0))
    None => fail("expected bearing outer diameter")
  }
  assert_true(
    motion_near(motion_connector(part, "face-positive").placement.trans.2, 7.0),
  )
}

///|
test "keyed shaft exposes ends and a keyway datum" {
  let part = match @motion.keyed_shaft(20.0, 40.0, 6.0, 3.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "shaft-a"))
  assert_true(motion_has_connector(part, "shaft-b"))
  let datum = motion_connector(part, "keyway-datum")
  assert_true(datum.kind is @common.MateKind::Datum)
  assert_true(datum.axis.1 > 0.99)
}

///|
test "compression spring exposes end datums" {
  let part = match @motion.compression_spring(20.0, 2.0, 40.0, 6) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "end-a"))
  assert_true(motion_has_connector(part, "end-b"))
}

///|
fn ok_motion(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn[T] ok_motion_spec(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "every public motion builder family exposes a connector" {
  let segments : Array[@motion.ShaftSegment] = [
    ok_motion_spec(@motion.ShaftSegment::new(10.0, 20.0)),
    ok_motion_spec(@motion.ShaftSegment::new(6.0, 15.0)),
  ]
  let builders : Array[(@common.Component, String)] = [
    (ok_motion(@motion.shaft(10.0, 40.0)), "shaft-a"),
    (ok_motion(@motion.stepped_shaft(segments)), "shaft-a"),
    (
      ok_motion(@motion.filleted_stepped_shaft([(10.0, 20.0), (6.0, 10.0)])),
      "shaft-a",
    ),
    (ok_motion(@motion.spacer(10.0, 5.0, 12.0)), "bore"),
    (ok_motion(@motion.bushing(10.0, 5.0, 12.0)), "bore"),
    (ok_motion(@motion.key(20.0, 6.0, 4.0)), "top-face"),
    (ok_motion(@motion.key_for_keyway(6.0, 3.0, 20.0)), "top-face"),
    (ok_motion(@motion.keyed_shaft(20.0, 40.0, 6.0, 3.0)), "shaft-a"),
    (
      ok_motion(@motion.bearing(ok_motion_spec(@motion.bearing_size("608")))),
      "bore",
    ),
    (
      ok_motion(
        @motion.deep_groove_bearing(ok_motion_spec(@motion.bearing_size("608"))),
      ),
      "outer-seat",
    ),
    (ok_motion(@motion.bearing_by_designation("608")), "bore"),
    (
      ok_motion(
        @motion.shielded_bearing(ok_motion_spec(@motion.bearing_size("608"))),
      ),
      "bore",
    ),
    (
      ok_motion(
        @motion.linear_bearing(
          ok_motion_spec(@motion.linear_bearing_size("LM8UU")),
        ),
      ),
      "bore",
    ),
    (ok_motion(@motion.linear_bearing_by_designation("LM8UU")), "bore"),
    (
      ok_motion(
        @motion.flanged_linear_bearing(
          ok_motion_spec(@motion.linear_bearing_size("LM8UU")),
        ),
      ),
      "bore",
    ),
    (ok_motion(@motion.compression_spring(20.0, 2.0, 40.0, 6)), "end-a"),
    (ok_motion(@motion.standoff(10.0, 20.0, 4.0)), "bore"),
    (ok_motion(@motion.dowel_pin(6.0, 20.0)), "shaft-a"),
    (ok_motion(@motion.gt2_pulley(20, 2.0, 10.0)), "bore"),
    (ok_motion(@motion.shaft_collar(10.0, 20.0, 12.0)), "bore"),
    (
      ok_motion(@motion.set_screw_shaft_collar(8.0, 16.0, 8.0)),
      "set-screw-thread",
    ),
    (
      ok_motion(@motion.clamp_shaft_collar(20.0, 40.0, 15.0)),
      "clamp-screw-thread",
    ),
    (
      ok_motion(@motion.v_wheel(@motion.VWheelSpec::openbuilds_solid_v())),
      "axle-bore",
    ),
    (
      ok_motion(
        @motion.emt_tube(ok_motion_spec(@motion.emt_size("1/2")), 300.0),
      ),
      "bore-a",
    ),
    (ok_motion(@motion.vslot_spacer()), "bore"),
    (ok_motion(@motion.vslot_eccentric_spacer()), "bore"),
    (ok_motion(@motion.smooth_idler(20.0, 8.0, 10.0)), "bore"),
    (
      ok_motion(
        @motion.emt_end_cap(ok_motion_spec(@motion.emt_size("1/2")), 3.0, 15.0),
      ),
      "plug",
    ),
    (
      ok_motion(
        @motion.emt_split_clamp(ok_motion_spec(@motion.emt_size("1/2")), 20.0),
      ),
      "bolt-hole",
    ),
    (ok_motion(@motion.rigid_coupling(8.0, 16.0, 20.0)), "bore-a"),
    (ok_motion(@motion.flanged_bearing_housing(22.0, 7.0)), "bearing-seat"),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !motion_has_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}

///|
test "smooth idler exposes bore, running surface, and flange rim" {
  let part = match
    @motion.smooth_idler(
      20.0,
      8.0,
      10.0,
      flange_diameter_mm=24.0,
      flange_thickness_mm=1.5,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true((x1 - x0 - 24.0).abs() < 1.0e-6)
  assert_true((z0 + 1.5).abs() < 1.0e-6)
  assert_true((z1 - 11.5).abs() < 1.0e-6)
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true((volume - 3845.31).abs() < 0.2)
  for
    name in [
      "bore", "outer-seat", "face-negative", "face-positive", "flange-seat",
    ] {
    if !motion_has_connector(part, name) {
      abort("smooth idler is missing connector " + name)
    }
  }
  let bore = motion_connector(part, "bore")
  match bore.depth_mm {
    Some(d) => assert_true((d - 13.0).abs() < 1.0e-9)
    None => fail("expected a bore depth")
  }
}

///|
test "plain smooth idler has no flange rim" {
  let part = match @motion.smooth_idler(20.0, 8.0, 10.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(motion_has_connector(part, "bore"))
  assert_true(!motion_has_connector(part, "flange-seat"))
  assert_true(part.layers().length() == 1)
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 10.0).abs() < 1.0e-6)
}

///|
test "smooth idler rejects impossible flanges" {
  assert_true(@motion.smooth_idler(20.0, 20.0, 10.0) is Err(_))
  assert_true(
    @motion.smooth_idler(
      20.0,
      8.0,
      10.0,
      flange_diameter_mm=18.0,
      flange_thickness_mm=1.0,
    )
    is Err(_),
  )
  assert_true(
    @motion.smooth_idler(
      20.0,
      8.0,
      10.0,
      flange_diameter_mm=24.0,
      flange_thickness_mm=0.0,
    )
    is Err(_),
  )
}
