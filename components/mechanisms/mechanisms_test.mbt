///|
test "hinge closed envelope, layers, and connectors" {
  let part = mech_ok(@mechanisms.hinge(40.0, 20.0, 6.0, 4.0, knuckles=3))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -22.0))
  assert_true(mech_close(x1, 22.0))
  assert_true(mech_close(y0, -20.0))
  assert_true(mech_close(y1, 20.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 6.0))
  // Two leaves plus three knuckles plus the pin.
  assert_eq(part.layers().length(), 6)
  for name in ["hinge-axis", "pin-bore", "leaf-face-a", "leaf-face-b"] {
    assert_true(mech_has_connector(part, name))
  }
  let bore = mech_connector(part, "pin-bore")
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(bore.gender is @common.MateGender::Female)
  assert_true(mech_close(bore.diameter_mm.unwrap(), 4.0))
  assert_true(mech_has_connector(part, "mount-hole-a-1"))
  assert_true(mech_has_connector(part, "mount-hole-b-2"))
}

///|
test "hinge open leaf expands the envelope below the base plane" {
  let part = mech_ok(
    @mechanisms.hinge(40.0, 20.0, 6.0, 4.0, knuckles=3, leaf_angle_deg=90.0),
  )
  let (_x0, _x1, _y0, _y1, z0, z1) = part.bounding_box()
  // Leaf B rotates below the base plane by its width minus the mid-plane.
  assert_true(mech_close(z0, 3.0 - 20.0))
  assert_true(mech_close(z1, 6.0))
}

///|
test "hinge rejects impossible pin and gap geometry" {
  assert_true(@mechanisms.hinge(40.0, 20.0, 6.0, 6.0, knuckles=3) is Err(_))
  assert_true(@mechanisms.hinge(40.0, 20.0, 6.0, 4.0, knuckles=1) is Err(_))
  assert_true(
    @mechanisms.hinge(40.0, 20.0, 6.0, 4.0, knuckles=3, knuckle_gap_mm=20.0)
    is Err(_),
  )
  assert_true(
    @mechanisms.hinge(40.0, 20.0, 6.0, 4.0, hole_diameter_mm=20.0) is Err(_),
  )
}

///|
test "clevis prongs carry aligned analytic pin bores" {
  let part = mech_ok(
    @mechanisms.clevis(
      30.0,
      20.0,
      6.0,
      5.0,
      8.0,
      6.0,
      shank_diameter_mm=10.0,
      shank_length_mm=20.0,
    ),
  )
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -15.0))
  assert_true(mech_close(x1, 15.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 10.0))
  assert_true(mech_close(z0, -20.0))
  assert_true(mech_close(z1, 6.0 + 5.0 + 8.0 + 5.0))
  let lower = mech_connector(part, "pin-bore-a")
  let upper = mech_connector(part, "pin-bore-b")
  assert_true(mech_close(lower.placement.trans.2, 6.0))
  assert_true(mech_close(upper.placement.trans.2, 6.0 + 5.0 + 8.0))
  assert_true(mech_close(upper.diameter_mm.unwrap(), 6.0))
  let thread = mech_connector(part, "rod-thread")
  assert_true(thread.kind is @common.MateKind::Threaded)
  assert_true(thread.gender is @common.MateGender::Male)
  assert_true(mech_has_connector(part, "fork-face"))
  assert_true(mech_has_connector(part, "eye-seat"))
  assert_true(part.features().has_omitted("thread"))
}

///|
test "clevis rejects a pin that does not fit its prong footprint" {
  assert_true(@mechanisms.clevis(10.0, 10.0, 5.0, 4.0, 5.0, 12.0) is Err(_))
  assert_true(@mechanisms.clevis(30.0, 20.0, 5.0, 4.0, 0.0, 6.0) is Err(_))
  assert_true(
    @mechanisms.clevis(30.0, 20.0, 5.0, 4.0, 5.0, 6.0, shank_diameter_mm=10.0)
    is Err(_),
  )
}

///|
test "clevis pin shank and head envelope" {
  let part = mech_ok(@mechanisms.clevis_pin(6.0, 30.0, 10.0, 2.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -5.0))
  assert_true(mech_close(x1, 5.0))
  assert_true(mech_close(y0, -5.0))
  assert_true(mech_close(y1, 5.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 30.0))
  let shaft = mech_connector(part, "shaft-end")
  assert_true(shaft.kind is @common.MateKind::CylindricalShaft)
  assert_true(shaft.gender is @common.MateGender::Male)
}

///|
test "linkage bar envelope, pivot holes, and adjustment slot" {
  let part = mech_ok(
    @mechanisms.linkage_bar(
      100.0,
      20.0,
      5.0,
      8.0,
      slot_length_mm=30.0,
      slot_width_mm=8.0,
    ),
  )
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -50.0))
  assert_true(mech_close(x1, 50.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 10.0))
  assert_true(mech_close(z0, 0.0))
  assert_true(mech_close(z1, 5.0))
  let pivot_a = mech_connector(part, "pivot-a")
  let pivot_b = mech_connector(part, "pivot-b")
  assert_true(mech_close(pivot_a.placement.trans.0, -40.0))
  assert_true(mech_close(pivot_b.placement.trans.0, 40.0))
  assert_true(mech_close(pivot_a.diameter_mm.unwrap(), 8.0))
  assert_true(mech_has_connector(part, "adjustment-slot"))
  assert_true(part.features().has_modeled("adjustment-slot"))
}

///|
test "linkage_lengths wrapper and validation" {
  let part = mech_ok(
    @mechanisms.linkage_bar_from_lengths(
      @cad.Length::mm(80.0),
      @cad.Length::mm(16.0),
      @cad.Length::mm(4.0),
      @cad.Length::mm(6.0),
    ),
  )
  let (x0, x1, _y0, _y1, _z0, _z1) = part.bounding_box()
  assert_true(mech_close(x1 - x0, 80.0))
  assert_true(@mechanisms.linkage_bar(100.0, 120.0, 5.0, 8.0) is Err(_))
  assert_true(@mechanisms.linkage_bar(100.0, 20.0, 5.0, 20.0) is Err(_))
  assert_true(
    @mechanisms.linkage_bar(
      100.0,
      20.0,
      5.0,
      8.0,
      slot_length_mm=76.0,
      slot_width_mm=8.0,
    )
    is Err(_),
  )
}

///|
test "clevis pin and lead screw nut resolve as nominal mate pairs" {
  let fork = mech_ok(@mechanisms.clevis(30.0, 20.0, 6.0, 5.0, 8.0, 6.0))
  let pin = mech_ok(@mechanisms.clevis_pin(6.0, 30.0, 10.0, 2.0))
  let pair = @common.MatePair::new(parent="pin-bore-a", child="shaft-end")
  let alignment = match
    pair.resolve(
      mech_connector(fork, "pin-bore-a"),
      mech_connector(pin, "shaft-end"),
    ) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(alignment.nominal_diameter_gap_mm(), 0.0))

  let rod = mech_ok(@mechanisms.rod_end(20.0, 6.0, 8.0, 8.0, 30.0))
  let eye_pair = @common.MatePair::new(parent="eye-bore", child="shaft-end")
  let eye_alignment = match
    eye_pair.resolve(
      mech_connector(rod, "eye-bore"),
      mech_connector(pin, "shaft-end"),
    ) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(eye_alignment.nominal_diameter_gap_mm(), 0.0))

  let screw = mech_ok(@mechanisms.lead_screw(8.0, 200.0))
  let nut = mech_ok(@mechanisms.lead_screw_nut(16.0, 20.0, 24.0, 4.0, 8.0, 2.0))
  let screw_pair = @common.MatePair::new(parent="thread", child="thread")
  let screw_alignment = match
    screw_pair.resolve(
      mech_connector(screw, "thread"),
      mech_connector(nut, "thread"),
    ) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  assert_true(mech_close(screw_alignment.nominal_diameter_gap_mm(), 0.0))
}

///|
test "rod end eye and shank envelope" {
  let part = mech_ok(@mechanisms.rod_end(20.0, 6.0, 8.0, 8.0, 30.0))
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true(mech_close(x0, -10.0))
  assert_true(mech_close(x1, 10.0))
  assert_true(mech_close(y0, -10.0))
  assert_true(mech_close(y1, 30.0))
  assert_true(mech_close(z0, -4.0))
  assert_true(mech_close(z1, 4.0))
  let bore = mech_connector(part, "eye-bore")
  assert_true(bore.kind is @common.MateKind::CylindricalBore)
  assert_true(bore.gender is @common.MateGender::Female)
  assert_true(mech_close(bore.diameter_mm.unwrap(), 6.0))
  let shank = mech_connector(part, "shank")
  assert_true(shank.kind is @common.MateKind::CylindricalShaft)
  assert_true(shank.gender is @common.MateGender::Male)
  assert_true(mech_has_connector(part, "rod-thread"))
  assert_true(@mechanisms.rod_end(20.0, 20.0, 8.0, 8.0, 30.0) is Err(_))
  assert_true(@mechanisms.rod_end(20.0, 6.0, 8.0, 20.0, 30.0) is Err(_))
}

///|
test "linkage design family builds defaults and named variants" {
  let family = match @mechanisms.linkage_family() {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_eq(family.parameter_names().length(), 6)
  let part = match family.build_values([]) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true(mech_close(x1 - x0, 120.0))
  assert_true(mech_close(y1 - y0, 24.0))
  let compact = match family.build_variant("compact") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (cx0, cx1, cy0, cy1, _cz0, _cz1) = compact.bounding_box()
  assert_true(mech_close(cx1 - cx0, 80.0))
  assert_true(mech_close(cy1 - cy0, 16.0))
  assert_true(family.build_values([("length", 500.0)]) is Err(_))
  assert_true(family.build_values([("unknown", 1.0)]) is Err(_))
}
