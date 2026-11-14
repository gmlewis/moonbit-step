///|
test "linear rail profile, envelope, and declared mounting holes" {
  let profile = match
    @mechanisms.linear_rail_profile(
      width_mm=20.0,
      height_mm=15.0,
      groove_width_mm=6.0,
      groove_depth_mm=2.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let rail = mech_ok(@mechanisms.linear_rail(profile, 300.0))
  let (x0, x1, y0, y1, z0, z1) = rail.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, 300.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 10.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 15.0))
  assert_true(mech_has_connector(rail, "rail-axis"))
  assert_true(mech_has_connector(rail, "rail-top"))
  assert_true(mech_has_connector(rail, "mount-hole-1"))
  assert_true(mech_has_connector(rail, "mount-hole-4"))
  assert_eq(rail.layers().length(), 2)
  let mount = mech_connector(rail, "mount-hole-1")
  assert_true(mount.kind is @common.MateKind::CylindricalBore)
  assert_true(mount.gender is @common.MateGender::Female)
  assert_true(mech_close(mount.depth_mm.unwrap(), 4.0))
  let top = mech_connector(rail, "rail-top")
  assert_true(top.kind is @common.MateKind::PlaneFace)
  assert_true(top.axis.2 > 0.99)
}

///|
test "linear carriage channel, bolt holes, and travel" {
  let profile = match
    @mechanisms.linear_rail_profile(
      width_mm=20.0,
      height_mm=15.0,
      groove_width_mm=6.0,
      groove_depth_mm=2.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let block = mech_ok(@mechanisms.linear_carriage(profile, 80.0, 50.0, 30.0))
  let (x0, x1, y0, y1, z0, z1) = block.bounding_box()
  assert_true(mech_close(x0, -40.0))
  assert_true(mech_close(x1, 40.0))
  assert_true(mech_close(y0, -25.0))
  assert_true(mech_close(y1, 25.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 30.0))
  let channel = mech_connector(block, "rail-channel")
  assert_true(mech_close(channel.diameter_mm.unwrap(), 20.06))
  let hole = mech_connector(block, "bolt-hole-1")
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
  assert_true(mech_close(hole.placement.trans.2, 15.03))
  match @mechanisms.linear_travel_mm(300.0, 80.0) {
    Ok(t) => assert_true(mech_close(t, 220.0))
    Err(e) => abort(e.message())
  }
  assert_true(@mechanisms.linear_travel_mm(80.0, 80.0) is Err(_))
  assert_true(@mechanisms.linear_carriage(profile, 80.0, 20.0, 30.0) is Err(_))
}

///|
test "lead screw, flanged nut, and travel envelope" {
  let screw = mech_ok(@mechanisms.lead_screw(8.0, 200.0, lead_mm=2.0))
  let (sx0, sx1, sy0, sy1, sz0, sz1) = screw.bounding_box()
  assert_true(mech_close(sx0, -4.0))
  assert_true(mech_close(sx1, 4.0))
  assert_true(mech_close(sy0, -4.0))
  assert_true(mech_close(sy1, 4.0))
  assert_true(mech_close(sz0, 0.0))
  assert_true(mech_close(sz1, 200.0))
  let thread = mech_connector(screw, "thread")
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.gender is @common.MateGender::Male)

  let nut = mech_ok(@mechanisms.lead_screw_nut(16.0, 20.0, 24.0, 4.0, 8.0, 2.0))
  let (nx0, nx1, ny0, ny1, nz0, nz1) = nut.bounding_box()
  assert_true(mech_close(nx0, -12.0))
  assert_true(mech_close(nx1, 12.0))
  assert_true(mech_close(ny0, -12.0))
  assert_true(mech_close(ny1, 12.0))
  assert_true(mech_close(nz0, 0.0))
  assert_true(mech_close(nz1, 20.0))
  let nut_thread = mech_connector(nut, "thread")
  assert_true(nut_thread.gender is @common.MateGender::Female)
  match @mechanisms.lead_screw_travel_mm(200.0, 20.0) {
    Ok(t) => assert_true(mech_close(t, 180.0))
    Err(e) => abort(e.message())
  }
  assert_true(
    @mechanisms.lead_screw_nut(16.0, 20.0, 12.0, 4.0, 8.0, 2.0) is Err(_),
  )
}

///|
test "belt loop pitch-length closure and envelope" {
  let expected = 2.0 * 100.0 + @math.PI * 20.0
  assert_true(
    mech_close(@mechanisms.belt_pitch_length_mm(20.0, 100.0), expected),
  )
  let belt = mech_ok(@mechanisms.belt_loop(20.0, 100.0, 2.0, 10.0))
  let (x0, x1, y0, y1, z0, z1) = belt.bounding_box()
  assert_true(mech_close(x0, -62.0))
  assert_true(mech_close(x1, 62.0))
  assert_true(mech_close(y0, -12.0))
  assert_true(mech_close(y1, 12.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 10.0))
  assert_true(mech_has_connector(belt, "pulley-a"))
  assert_true(mech_has_connector(belt, "pulley-b"))
  match @mechanisms.belt_center_distance_for_pitch_length(expected, 20.0) {
    Ok(c) => assert_true(mech_close(c, 100.0))
    Err(e) => abort(e.message())
  }
  let from_pitch = mech_ok(
    @mechanisms.belt_loop_for_pitch_length(expected, 20.0, 2.0, 10.0),
  )
  let (_fx0, _fx1, _fy0, _fy1, _fz0, fz1) = from_pitch.bounding_box()
  assert_true(mech_close(fz1, 10.0))
  assert_true(
    @mechanisms.belt_loop_for_pitch_length(10.0, 20.0, 2.0, 10.0) is Err(_),
  )
}

///|
test "eccentric cam lift curve and roller follower envelope" {
  assert_true(
    mech_close(@mechanisms.eccentric_cam_radius_mm(20.0, 5.0, 0.0), 25.0),
  )
  assert_true(
    mech_close(@mechanisms.eccentric_cam_radius_mm(20.0, 5.0, 180.0), 15.0),
  )
  assert_true(
    mech_close(@mechanisms.eccentric_cam_lift_mm(20.0, 5.0, 0.0), 10.0),
  )
  assert_true(
    mech_close(@mechanisms.eccentric_cam_lift_mm(20.0, 5.0, 180.0), 0.0),
  )
  let cam = mech_ok(@mechanisms.eccentric_cam(20.0, 5.0, 8.0, 6.0))
  let (x0, x1, y0, y1, z0, z1) = cam.bounding_box()
  assert_true(mech_close(x0, -15.0))
  assert_true(mech_close(x1, 25.0))
  assert_true(mech_close(y0, -20.0))
  assert_true(mech_close(y1, 20.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 8.0))
  assert_true(mech_has_connector(cam, "rotation-bore"))
  assert_true(mech_has_connector(cam, "nose-datum"))
  assert_true(@mechanisms.eccentric_cam(20.0, 20.0, 8.0, 6.0) is Err(_))
  assert_true(@mechanisms.eccentric_cam(20.0, 5.0, 8.0, 31.0) is Err(_))

  let roller = mech_ok(@mechanisms.roller_follower(10.0, 8.0, 5.0, 4.0, 10.0))
  let (rx0, rx1, _ry0, _ry1, rz0, rz1) = roller.bounding_box()
  assert_true(mech_close(rx0, -5.0))
  assert_true(mech_close(rx1, 5.0))
  assert_true(mech_close(rz0, -1.0))
  assert_true(mech_close(rz1, 9.0))
  let surface = mech_connector(roller, "roller-surface")
  assert_true(surface.kind is @common.MateKind::CylindricalShaft)
  assert_true(@mechanisms.roller_follower(10.0, 8.0, 5.0, 5.0, 10.0) is Err(_))
}

///|
test "Oldham coupling axial envelope and bores" {
  let part = mech_ok(
    @mechanisms.oldham_coupling(5.0, 20.0, 8.0, 18.0, 3.0, 4.0),
  )
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -10.0))
  assert_true(mech_close(x1, 10.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 10.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 19.0))
  assert_eq(part.layers().length(), 9)
  let slot = mech_connector(part, "slot-a")
  assert_true(slot.kind is @common.MateKind::ProfileSlot)
  assert_true(part.features().has_modeled("hub-slots"))
  let bore_a = mech_connector(part, "bore-a")
  let bore_b = mech_connector(part, "bore-b")
  assert_true(mech_close(bore_a.diameter_mm.unwrap(), 5.0))
  assert_true(mech_close(bore_b.diameter_mm.unwrap(), 5.0))
  assert_true(mech_close(bore_a.placement.trans.2, 0.0))
  assert_true(mech_close(bore_b.placement.trans.2, 19.0))
}

///|
test "extension and torsion springs keep their free length" {
  let extension = mech_ok(
    @mechanisms.extension_spring(20.0, 2.0, 40.0, 8, leg_length_mm=10.0),
  )
  let (x0, x1, y0, y1, z0, z1) = extension.bounding_box()
  assert_true(mech_close(x0, -11.0))
  assert_true(mech_close(x1, 20.0))
  assert_true(mech_close(y0, -11.0))
  assert_true(mech_close(y1, 11.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 40.0))
  assert_true(mech_has_connector(extension, "hook-leg-a"))
  assert_true(mech_has_connector(extension, "hook-leg-b"))
  assert_true(extension.features().has_omitted("closed-hook-loops"))

  let torsion = mech_ok(
    @mechanisms.torsion_spring(20.0, 2.0, 40.0, 8, leg_length_mm=10.0),
  )
  let (tx0, tx1, ty0, ty1, tz0, tz1) = torsion.bounding_box()
  assert_true(mech_close(tx0, -11.0))
  assert_true(mech_close(tx1, 11.0))
  assert_true(mech_close(ty0, -11.0))
  assert_true(mech_close(ty1, 11.0))
  assert_true(mech_close(tz0, 0.0))
  assert_true(mech_close(tz1, 40.0))
  assert_true(mech_has_connector(torsion, "leg-a"))
  assert_true(mech_has_connector(torsion, "leg-b"))

  assert_true(
    @mechanisms.extension_spring(20.0, 2.0, 40.0, 8, leg_length_mm=10.0)
    is Ok(_),
  )
  assert_true(@mechanisms.torsion_spring(1.0, 2.0, 40.0, 8) is Err(_))
}

///|
test "snap latch engagement envelope" {
  let part = mech_ok(@mechanisms.snap_latch(40.0, 2.0, 10.0, 3.0, 5.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, 40.0))
  assert_true(mech_close(y0, -3.0))
  assert_true(mech_close(y1, 2.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 10.0))
  let hook = mech_connector(part, "hook-engagement")
  assert_true(mech_close(hook.depth_mm.unwrap(), 3.0))
  assert_true(@mechanisms.snap_latch(10.0, 2.0, 10.0, 3.0, 10.0) is Err(_))
}

///|
test "O-ring torus envelope and volume" {
  let part = mech_ok(@mechanisms.o_ring(20.0, 4.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -14.0))
  assert_true(mech_close(x1, 14.0))
  assert_true(mech_close(y0, -14.0))
  assert_true(mech_close(y1, 14.0))
  assert_true(mech_close(z0, -2.0))
  assert_true(mech_close(z1, 2.0))
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = @mechanisms.o_ring_volume_mm3(20.0, 4.0)
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
  match @mechanisms.o_ring_squeeze_mm(4.0, 3.0) {
    Ok(s) => assert_true(mech_close(s, 1.0))
    Err(e) => abort(e.message())
  }
  assert_true(@mechanisms.o_ring_squeeze_mm(4.0, 4.0) is Err(_))
}

///|
test "grooved shaft real groove and squeeze envelope" {
  let part = mech_ok(@mechanisms.grooved_shaft(20.0, 50.0, 4.0, 2.0, 20.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -10.0))
  assert_true(mech_close(x1, 10.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 10.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 50.0))
  let seat = mech_connector(part, "groove-seat")
  assert_true(mech_close(seat.diameter_mm.unwrap(), 16.0))
  assert_true(mech_close(seat.placement.trans.2, 20.0))
  let volume = match part.layers()[0].shape.analysis_volume() {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let expected = @math.PI * 10.0 * 10.0 * 50.0 -
    @math.PI * (10.0 * 10.0 - 8.0 * 8.0) * 4.0
  assert_true((volume - expected).abs() < 1.0e-6 * expected)
  assert_true(@mechanisms.grooved_shaft(20.0, 50.0, 4.0, 10.0, 20.0) is Err(_))
  assert_true(@mechanisms.grooved_shaft(20.0, 50.0, 4.0, 2.0, 1.0) is Err(_))
}

///|
test "L bracket legs, real holes, and gusset" {
  let part = mech_ok(@mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, 60.0))
  assert_true(mech_close(y0, -15.0))
  assert_true(mech_close(y1, 15.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 50.0))
  assert_true(mech_has_connector(part, "base-hole-1"))
  assert_true(mech_has_connector(part, "base-hole-2"))
  assert_true(mech_has_connector(part, "upright-hole-1"))
  assert_true(mech_has_connector(part, "upright-hole-2"))
  let hole = mech_connector(part, "base-hole-1")
  assert_true(hole.kind is @common.MateKind::CylindricalBore)
  assert_true(mech_close(hole.placement.trans.0, 8.0))
  let upright = mech_connector(part, "upright-hole-1")
  assert_true(mech_close(upright.placement.trans.2, 8.0))
  let gusseted = mech_ok(
    @mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0, gusset_mm=12.0),
  )
  assert_true(mech_has_connector(gusseted, "gusset-datum"))
  assert_true(gusseted.features().has_modeled("corner-gusset"))
  assert_true(
    @mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0, gusset_mm=60.0) is Err(_),
  )
}

///|
test "tapped boss blind bore and declared thread" {
  let part = mech_ok(
    @mechanisms.tapped_boss(16.0, 20.0, 24.0, 4.0, 6.0, 1.0, 10.0),
  )
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -12.0))
  assert_true(mech_close(x1, 12.0))
  assert_true(mech_close(y0, -12.0))
  assert_true(mech_close(y1, 12.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 20.0))
  let thread = mech_connector(part, "thread")
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.gender is @common.MateGender::Female)
  assert_true(mech_close(thread.depth_mm.unwrap(), 10.0))
  let bore = mech_connector(part, "bore")
  assert_true(mech_close(bore.diameter_mm.unwrap(), 4.917468))
  let counterbored = mech_ok(
    @mechanisms.tapped_boss(
      16.0,
      20.0,
      24.0,
      4.0,
      6.0,
      1.0,
      8.0,
      counterbore_diameter_mm=8.0,
      counterbore_depth_mm=4.0,
    ),
  )
  assert_true(mech_has_connector(counterbored, "counterbore"))
  assert_true(counterbored.features().has_modeled("counterbore"))
  assert_true(
    @mechanisms.tapped_boss(16.0, 20.0, 16.0, 4.0, 6.0, 1.0, 10.0) is Err(_),
  )
}

///|
test "rack tooth geometry and pinion layout" {
  let part = mech_ok(@mechanisms.rack_gear(2.0, 10, 6.0, 10.0))
  let pitch = @math.PI * 2.0
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, 0.0))
  assert_true(mech_close(x1, pitch * 10.0))
  assert_true(mech_close(y0, 0.0))
  assert_true(mech_close(y1, 6.0 + 2.25 * 2.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 10.0))
  let pitch_plane = mech_connector(part, "pitch-plane")
  assert_true(mech_close(pitch_plane.placement.trans.1, 6.0 + 1.25 * 2.0))
  assert_true(mech_has_connector(part, "mount-hole-1"))
  let layout = match @mechanisms.rack_pinion_layout(2.0, 10, 20) {
    Ok(l) => l
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(layout.center_distance_mm, 20.0))
  assert_true(
    mech_close(layout.rack_travel_per_revolution_mm, @math.PI * 2.0 * 20.0),
  )
  assert_true(mech_close(layout.pitch_line_mm, 2.5))
}

///|
test "unequal belt loop tangent geometry and pitch closure" {
  let pitch = @mechanisms.belt_pitch_length_mm_unequal(20.0, 40.0, 100.0)
  // Exact formula: pi(r1+r2) + 2*alpha*dr + 2*sqrt(C^2-dr^2).
  let alpha = @math.asin(10.0 / 100.0)
  let expected = @math.PI * 30.0 +
    2.0 * alpha * 10.0 +
    2.0 * (100.0 * 100.0 - 10.0 * 10.0).sqrt()
  assert_true((pitch - expected).abs() < 1.0e-9)
  let belt = mech_ok(
    @mechanisms.belt_loop_unequal(20.0, 40.0, 100.0, 2.0, 10.0),
  )
  let (x0, x1, y0, y1, z0, z1) = belt.bounding_box()
  assert_true(mech_close(x0, -62.0))
  assert_true(mech_close(x1, 72.0))
  assert_true(mech_close(y0, -22.0))
  assert_true(mech_close(y1, 22.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 10.0))
  assert_true(mech_has_connector(belt, "pulley-a"))
  assert_true(mech_has_connector(belt, "pulley-b"))
  let solved = match
    @mechanisms.belt_center_distance_for_pitch_length_unequal(pitch, 20.0, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true((solved - 100.0).abs() < 1.0e-7)
  // Equal diameters reduce to the symmetric belt.
  let equal = mech_ok(
    @mechanisms.belt_loop_unequal(20.0, 20.0, 100.0, 2.0, 10.0),
  )
  let (ex0, ex1, ey0, ey1, _ez0, _ez1) = equal.bounding_box()
  assert_true(mech_close(ex0, -62.0))
  assert_true(mech_close(ex1, 62.0))
  assert_true(mech_close(ey0, -12.0))
  assert_true(mech_close(ey1, 12.0))
  assert_true(
    mech_close(
      @mechanisms.belt_pitch_length_mm_unequal(20.0, 20.0, 100.0),
      @mechanisms.belt_pitch_length_mm(20.0, 100.0),
    ),
  )
  assert_true(
    @mechanisms.belt_loop_unequal(20.0, 40.0, 10.0, 2.0, 10.0) is Err(_),
  )
  // Reversing which pulley is larger is symmetric in pitch and mirrors the box.
  let reversed = mech_ok(
    @mechanisms.belt_loop_unequal(40.0, 20.0, 100.0, 2.0, 10.0),
  )
  let (rx0, rx1, ry0, ry1, _rz0, _rz1) = reversed.bounding_box()
  assert_true(mech_close(rx0, -72.0))
  assert_true(mech_close(rx1, 62.0))
  assert_true(mech_close(ry0, -22.0))
  assert_true(mech_close(ry1, 22.0))
  assert_true(
    (@mechanisms.belt_pitch_length_mm_unequal(40.0, 20.0, 100.0) - pitch).abs() <
    1.0e-9,
  )
}

///|
test "extension spring closed end loops" {
  let part = mech_ok(
    @mechanisms.extension_spring(20.0, 2.0, 40.0, 8, hook_loop_radius_mm=5.0),
  )
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -11.0))
  assert_true(mech_close(x1, 21.0))
  assert_true(mech_close(y0, -11.0))
  assert_true(mech_close(y1, 11.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 40.0))
  assert_eq(part.layers().length(), 3)
  assert_true(mech_has_connector(part, "hook-loop-a"))
  assert_true(mech_has_connector(part, "hook-loop-b"))
  assert_true(!mech_has_connector(part, "hook-leg-a"))
  assert_true(part.features().has_modeled("end-loops"))
  assert_true(part.features().has_omitted("axial-hook-bend"))
  assert_true(
    @mechanisms.extension_spring(20.0, 2.0, 40.0, 8, hook_loop_radius_mm=1.0)
    is Err(_),
  )
}

///|
test "four-bar layout closes and reports Grashof" {
  let pose = match @mechanisms.four_bar_layout(40.0, 10.0, 40.0, 30.0, 0.0) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(mech_dist(pose.crank_joint, pose.rocker_joint), 40.0))
  assert_true(mech_close(mech_dist(pose.rocker_joint, pose.ground_pivot), 30.0))
  assert_true(mech_close(pose.crank_joint.0, 10.0))
  assert_true(pose.grashof)
  assert_true(pose.crank_rocker)
  let mirror = match
    @mechanisms.four_bar_layout(40.0, 10.0, 40.0, 30.0, 0.0, branch=-1) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(mirror.rocker_joint.1, -pose.rocker_joint.1))
  let toggle = match
    @mechanisms.four_bar_layout(40.0, 10.0, 40.0, 30.0, 180.0) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(
    mech_close(mech_dist(toggle.crank_joint, toggle.rocker_joint), 40.0),
  )
  assert_true(
    mech_close(mech_dist(toggle.rocker_joint, toggle.ground_pivot), 30.0),
  )
  let non_grashof = match
    @mechanisms.four_bar_layout(40.0, 30.0, 25.0, 20.0, 0.0) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  assert_true(!non_grashof.grashof)
  assert_true(@mechanisms.four_bar_layout(40.0, 10.0, 5.0, 5.0, 0.0) is Err(_))
  assert_true(@mechanisms.four_bar_layout(0.0, 10.0, 20.0, 20.0, 0.0) is Err(_))
}

///|
test "ANSI #40 16T sprocket matches the measured envelope" {
  let part = mech_ok(@mechanisms.ansi40_sprocket(16))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x1 - 36.589026).abs() < 1.0e-4)
  assert_true((x0 + 36.589026).abs() < 1.0e-4)
  assert_true((y1 - 36.589026).abs() < 1.0e-4)
  assert_true((y0 + 36.589026).abs() < 1.0e-4)
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 12.6))
  assert_eq(part.layers().length(), 2)
  let bore = mech_connector(part, "bore")
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(mech_close(bore.diameter_mm.unwrap(), 10.0))
  assert_true(mech_has_connector(part, "pitch-circle"))
  assert_true(mech_has_connector(part, "hub-seat"))
  assert_true(part.features().has_modeled("tooth-envelope"))
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true((volume - 24544.2).abs() < 1.0)
  assert_true(
    (@mechanisms.sprocket_tip_arc_half_angle_deg(16) - 3.17475).abs() < 1.0e-4,
  )
  assert_true(
    (@mechanisms.sprocket_tip_arc_half_angle_deg(24) - 1.88625).abs() < 1.0e-4,
  )
  let part24 = mech_ok(@mechanisms.ansi40_sprocket(24))
  let (bx0, bx1, _by0, _by1, _bz0, bz1) = part24.bounding_box()
  assert_true((bx1 - 52.68924).abs() < 1.0e-4)
  assert_true((bx0 + 52.68924).abs() < 1.0e-4)
  assert_true(mech_close(bz1, 12.6))
  assert_true(@mechanisms.ansi40_sprocket(8) is Err(_))
  assert_true(
    @mechanisms.roller_chain_sprocket_spec(
      pitch_mm=12.7,
      teeth=16,
      roller_diameter_mm=60.0,
    )
    is Err(_),
  )
  assert_true(
    @mechanisms.roller_chain_sprocket_spec(
      pitch_mm=12.7,
      teeth=16,
      roller_diameter_mm=7.9,
      tip_arc_half_angle_deg=20.0,
    )
    is Err(_),
  )
}

///|
test "roller-chain path length closes around two sprockets" {
  let length = match
    @mechanisms.roller_chain_path_length_mm(12.7, 16, 16, 100.0) {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
  let r = @mechanisms.sprocket_pitch_radius_mm(12.7, 16)
  assert_true((length - (2.0 * 100.0 + @math.PI * 2.0 * r)).abs() < 1.0e-9)
  assert_true(
    @mechanisms.roller_chain_path_length_mm(12.7, 16, 24, 10.0) is Err(_),
  )
}

///|
test "ANSI #40 10-pitch chain segment matches the layout reference" {
  let part = mech_ok(@mechanisms.ansi40_chain_segment(10))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -6.0))
  assert_true(mech_close(x1, 133.0))
  assert_true(mech_close(y0, -6.0))
  assert_true(mech_close(y1, 6.0))
  assert_true((z0 + 7.135).abs() < 1.0e-5)
  assert_true((z1 - 7.135).abs() < 1.0e-5)
  assert_eq(part.layers().length(), 42)
  let mut first_plate_z = 0.0
  let mut second_plate_z = 0.0
  for layer in part.layers() {
    if layer.name.contains("plate-1-negative") {
      first_plate_z = layer.placement.trans.2
    }
    if layer.name.contains("plate-2-negative") {
      second_plate_z = layer.placement.trans.2
    }
  }
  // Adjacent links must alternate between the inner and outer plate levels so
  // their stadium ends do not intersect at a shared pin.

  assert_true(second_plate_z < first_plate_z - 1.5)
  assert_true(mech_has_connector(part, "pin-a"))
  assert_true(mech_has_connector(part, "pin-b"))
  assert_true(mech_has_connector(part, "pitch-line"))
  let mut volume = 0.0
  for layer in part.layers() {
    volume += match layer.shape.analysis_volume() {
      Ok(v) => v
      Err(e) => abort(e.message())
    }
  }
  assert_true((volume - 12273.215).abs() < 0.1)
  assert_true(@mechanisms.ansi40_chain_segment(0) is Err(_))
  assert_true(
    @mechanisms.chain_segment_spec(
      pitch_mm=12.7,
      pitches=1,
      pin_diameter_mm=5.0,
    )
    is Err(_),
  )
}
