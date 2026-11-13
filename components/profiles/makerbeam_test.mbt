///|
fn mb_close(a : Double, b : Double, tol : Double) -> Bool {
  (a - b).abs() <= tol
}

///|
fn mb_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn mb_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn mb_connector(
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
test "MakerBeam 10 x 10 drawing dimensions" {
  let profile = @profiles.MakerBeamProfile::mb_1010()
  assert_eq(profile.designation(), "MakerBeam-1010")
  assert_eq(profile.slot_count(), 4)
  assert_true(mb_close(profile.size_mm, 10.0, 1.0e-12))
  assert_true(mb_close(profile.slot_width_mm, 3.0, 1.0e-12))
  assert_true(mb_close(profile.lip_thickness_mm, 1.0, 1.0e-12))
  assert_true(mb_close(profile.core_width_mm, 4.0, 1.0e-12))
  assert_true(mb_close(profile.bore_diameter_mm, 2.5, 1.0e-12))
  // The drawing's 48.75 mm^2 sharp section area.
  assert_true(mb_close(profile.section_area_mm2(), 48.75, 0.01))
}

///|
test "MakerBeam section outline has the drawing coordinates" {
  let profile = @profiles.MakerBeamProfile::mb_1010()
  let pts = profile.section_points()
  assert_eq(pts.length(), 36)
  // Outer envelope and slot-mouth vertices from the drawing.
  let wanted : Array[@cad.Vec2] = [
    (5.0, 5.0),
    (-5.0, 5.0),
    (1.5, 5.0),
    (-1.5, 5.0),
    (1.5, 4.0),
    (-1.5, 4.0),
    (3.293, 4.0),
    (-3.293, 4.0),
    (1.0, 2.0),
    (-1.0, 2.0),
  ]
  for target in wanted {
    let mut found = false
    for point in pts {
      if mb_close(point.0, target.0, 1.0e-9) &&
        mb_close(point.1, target.1, 1.0e-9) {
        found = true
      }
    }
    if !found {
      abort("missing section vertex (\{target.0}, \{target.1})")
    }
  }
}

///|
test "MakerBeam extrusion is one analytic solid" {
  let profile = @profiles.MakerBeamProfile::mb_1010()
  let part = mb_ok(@profiles.makerbeam_extrusion(profile, 100.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mb_close(x0, -5.0, 1.0e-9))
  assert_true(mb_close(x1, 5.0, 1.0e-9))
  assert_true(mb_close(y0, -5.0, 1.0e-9))
  assert_true(mb_close(y1, 5.0, 1.0e-9))
  assert_true(mb_close(z0, 0.0, 1.0e-9))
  assert_true(mb_close(z1, 100.0, 1.0e-9))
  assert_eq(part.layers().length(), 1)
  let layer = part.layers()[0]
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  // 48.7473 mm^2 x 100 mm.
  assert_true(mb_close(volume, 4874.73, 0.5))
  let section = match layer.shape.section_at_local(50.0) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(mb_close(section.area_mm2, 48.7473, 0.01))
}

///|
test "MakerBeam centre bore is an analytic cylinder" {
  let profile = @profiles.MakerBeamProfile::mb_1010()
  let part = mb_ok(@profiles.makerbeam_extrusion(profile, 100.0))
  let layer = part.layers()[0]
  let inventory = layer.shape.surface_inventory()
  // The sharp outline contributes planes only; the four-arc bore loop is a
  // single analytic cylinder in the compiler.
  assert_eq(inventory.cylinder, 4)
  assert_eq(profile.holes().length(), 1)
}

///|
test "MakerBeam connectors cover slots, ends, and end threads" {
  let profile = @profiles.MakerBeamProfile::mb_1010()
  let part = mb_ok(@profiles.makerbeam_extrusion(profile, 100.0))
  for
    name in [
      "slot-x-plus", "slot-x-minus", "slot-y-plus", "slot-y-minus", "end-a", "end-b",
      "core-bore", "end-thread-a", "end-thread-b",
    ] {
    if !mb_has_connector(part, name) {
      abort("missing connector " + name)
    }
  }
  let slot = mb_connector(part, "slot-x-plus")
  match slot.diameter_mm {
    Some(d) => assert_true(mb_close(d, 3.0, 1.0e-12))
    None => fail("slot connector should carry the 3 mm opening")
  }
  let thread = mb_connector(part, "end-thread-a")
  assert_true(thread.kind is @common.MateKind::Threaded)
  match thread.depth_mm {
    Some(d) => assert_true(mb_close(d, 8.0, 1.0e-12))
    None => fail("end thread should carry its 8 mm depth")
  }
  let core = mb_connector(part, "core-bore")
  match core.diameter_mm {
    Some(d) => assert_true(mb_close(d, 2.5, 1.0e-12))
    None => fail("core bore should carry its 2.5 mm diameter")
  }
}

///|
test "MakerBeam outer corner radius is optional and exact" {
  let sharp = @profiles.MakerBeamProfile::mb_1010()
  let rounded = match
    @profiles.MakerBeamProfile::custom(
      name="MakerBeam-1010-r02",
      size_mm=10.0,
      slot_width_mm=3.0,
      lip_thickness_mm=1.0,
      core_width_mm=4.0,
      bore_diameter_mm=2.5,
      lip_undercut_half_mm=3.293,
      floor_undercut_half_mm=1.0,
      corner_radius_mm=0.2,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  // Four outer corners lose r^2 - pi r^2 / 4 each; the bbox stays 10 x 10.
  assert_true(rounded.section_area_mm2() < sharp.section_area_mm2())
  assert_true(
    mb_close(
      sharp.section_area_mm2() - rounded.section_area_mm2(),
      0.0343,
      0.002,
    ),
  )
  let part = mb_ok(@profiles.makerbeam_extrusion(rounded, 100.0))
  let (x0, x1, _y0, _y1, _z0, _z1) = part.bounding_box()
  assert_true(mb_close(x0, -5.0, 1.0e-9))
  assert_true(mb_close(x1, 5.0, 1.0e-9))
  let layer = part.layers()[0]
  let volume = match layer.shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  assert_true(mb_close(volume, 4871.3, 0.5))
}

///|
test "MakerBeam validation rejects impossible sections" {
  // Slot wider than the profile.
  assert_true(
    @profiles.MakerBeamProfile::custom(
      name="bad",
      size_mm=10.0,
      slot_width_mm=11.0,
      lip_thickness_mm=1.0,
      core_width_mm=4.0,
      bore_diameter_mm=2.5,
      lip_undercut_half_mm=3.293,
      floor_undercut_half_mm=1.0,
    )
    is Err(_),
  )
  // Bore wider than the core.
  assert_true(
    @profiles.MakerBeamProfile::custom(
      name="bad",
      size_mm=10.0,
      slot_width_mm=3.0,
      lip_thickness_mm=1.0,
      core_width_mm=2.0,
      bore_diameter_mm=2.5,
      lip_undercut_half_mm=3.293,
      floor_undercut_half_mm=1.0,
    )
    is Err(_),
  )
  // Undercut not wider than the slot.
  assert_true(
    @profiles.MakerBeamProfile::custom(
      name="bad",
      size_mm=10.0,
      slot_width_mm=3.0,
      lip_thickness_mm=1.0,
      core_width_mm=4.0,
      bore_diameter_mm=2.5,
      lip_undercut_half_mm=1.4,
      floor_undercut_half_mm=1.0,
    )
    is Err(_),
  )
  // Floor undercut wider than the lip undercut.
  assert_true(
    @profiles.MakerBeamProfile::custom(
      name="bad",
      size_mm=10.0,
      slot_width_mm=3.0,
      lip_thickness_mm=1.0,
      core_width_mm=4.0,
      bore_diameter_mm=2.5,
      lip_undercut_half_mm=2.0,
      floor_undercut_half_mm=2.5,
    )
    is Err(_),
  )
  // Non-positive length.
  assert_true(
    @profiles.makerbeam_extrusion(@profiles.MakerBeamProfile::mb_1010(), 0.0)
    is Err(_),
  )
}
