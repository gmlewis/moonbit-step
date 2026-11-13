///|
test "fastener catalogue carries features and parameters" {
  let entries = @catalog.fastener_catalog()
  assert_true(entries.length() >= 9)
  let screw = match @catalog.lookup(entries, "ISO 4762 - M4 x 20") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(screw.family == "hexagon socket head cap screw")
  assert_true(screw.standard == "ISO 4762:2004")
  assert_true(screw.features.has_modeled("head-chamfer"))
  assert_true(screw.supported_parameters.any(fn(p) { p == "length" }))
  assert_true(screw.detail_levels.any(fn(d) { d == "Detailed" }))
  assert_true(screw.provenance.contains("ISO 4762"))
}

///|
test "catalogue lookup rejects an unknown designation" {
  let entries = @catalog.fastener_catalog()
  match @catalog.lookup(entries, "ISO 9999 - M4") {
    Ok(_) => abort("expected an unknown-designation error")
    Err(@catalog.UnknownDesignation(name)) =>
      assert_true(name.contains("ISO 9999"))
  }
}

///|
test "catalogue query filters by standard" {
  let entries = @catalog.full_catalog()
  let nuts = @catalog.query(entries, standard="ISO 4032:2023")
  assert_eq(nuts.length(), 3)
  assert_true(nuts.all(fn(e) { e.features.has_modeled("nut-face-chamfer") }))
}

///|
test "bearing catalogue lists analytic spheres" {
  let entries = @catalog.bearing_catalog()
  assert_eq(entries.length(), @motion.bearing_designations().length())
  let bearing = match @catalog.lookup(entries, "Bearing 608") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(bearing.features.has_modeled("ball-sphere"))
  assert_true(bearing.features.omission_reason("seal") is Some(_))
}

///|
test "profile catalogue is explicit about the generic envelope" {
  let entries = @catalog.profile_catalog()
  assert_eq(entries.length(), 8)
  let p2020 = match
    @catalog.lookup(entries, "Generic T-slot generic-2020 x 100") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(p2020.supported_parameters.any(fn(p) { p == "corner_radius" }))
  assert_true(p2020.standard.contains("Generic"))
  assert_true(p2020.features.has_modeled("t-slot-cavities"))
}

///|
test "gear catalogue records modeled and omitted features" {
  let entries = @catalog.gear_catalog()
  assert_eq(entries.length(), 2)
  let spur = match @catalog.lookup(entries, "Spur gear m2-z20") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(spur.features.has_modeled("involute-tooth-envelope"))
  assert_true(spur.features.omission_reason("root-fillet") is Some(_))
  let ring = match @catalog.lookup(entries, "Internal ring gear m2 z36") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  // The exact internal involute envelope is now modelled rather than omitted.
  assert_true(ring.features.has_modeled("internal-involute-tooth-envelope"))
  assert_true(ring.features.has_approximated("internal-involute-flank"))
  assert_true(
    ring.features.omission_reason("exact-involute-internal-envelope") is None,
  )
}

///|
test "motion catalogue carries the keyed shaft and key" {
  let entries = @catalog.motion_catalog()
  assert_eq(entries.length(), 2)
  let shaft = match
    @catalog.lookup(entries, "Keyed shaft d20 x 40, keyway 6 x 3.5") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(shaft.features.has_modeled("keyway"))
  assert_true(shaft.features.has_omitted("keyway-end-radius"))
  assert_true(shaft.supported_parameters.any(fn(p) { p == "keyway_depth" }))
  assert_eq(
    @catalog.query(@catalog.full_catalog(), family="keyed shaft").length(),
    1,
  )
}

///|
test "new construction and motion catalogue families are discoverable" {
  let hardware = @catalog.extrusion_hardware_catalog()
  assert_eq(hardware.length(), 5)
  assert_true(hardware.any(fn(e) { e.family == "extrusion T-nut" }))
  assert_true(hardware.any(fn(e) { e.family == "heat-set threaded insert" }))
  let tnut = match @catalog.lookup(hardware, "Extrusion T-nut M3, slot 5 mm") {
    Ok(e) => e
    Err(err) => abort(err.message())
  }
  assert_true(tnut.features.has_modeled("hexagonal-prism"))
  assert_true(tnut.supported_parameters.any(fn(p) { p == "slot_width" }))

  let linear = @catalog.linear_bearing_catalog()
  assert_eq(linear.length(), 2)
  assert_true(linear.any(fn(e) { e.family == "linear ball bushing" }))
  assert_true(
    linear.any(fn(e) { e.family == "flanged linear bushing housing" }),
  )

  let motors = @catalog.motor_catalog()
  assert_eq(motors.length(), 2)
  assert_true(motors.all(fn(e) { e.family == "stepper motor envelope" }))

  let stock = @catalog.stock_catalog()
  assert_eq(stock.length(), 2)
  assert_true(stock.any(fn(e) { e.family == "steel angle section" }))
  assert_true(stock.any(fn(e) { e.family == "flat plate blank" }))
}
