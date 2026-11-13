///|
fn mate_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
test "a screw mates a nut by named connectors" {
  let nut = match @fasteners.iso4032_nut(@standards.MetricSize::M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let screw = match @fasteners.iso4762_screw(@standards.MetricSize::M4, 20.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="bore",
    child="shaft",
    description="M4 screw through an M4 nut",
  )
  let assembly = @assemblies.Assembly::new(name="screw-and-nut").add(
    nut,
    instance_name="nut",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("nut", screw, pair, instance_name="screw") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(mate_near(alignment.placement.trans.2, 20.0))
  assert_true(alignment.insertion_anti_parallel)
  assert_true(mate_near(alignment.nominal_diameter_gap_mm(), 0.0))
  assert_true(mate_near(alignment.declared_clearance_mm(), 0.0))
}

///|
test "a shaft mates a bearing bore by named connectors" {
  let bearing = match @motion.bearing_by_designation("608") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let shaft = match @motion.shaft(8.0, 30.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(parent="bore", child="shaft-a")
  let assembly = @assemblies.Assembly::new(name="shaft-and-bearing").add(
    bearing,
    instance_name="bearing",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("bearing", shaft, pair, instance_name="shaft") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  assert_true(mate_near(alignment.placement.trans.2, 0.0))
  assert_true(mate_near(alignment.placement.trans.0, 0.0))
  assert_true(mate_near(alignment.nominal_diameter_gap_mm(), 0.0))
}

///|
test "a NEMA motor pilot mates a plate bore by named connectors" {
  let holes : Array[@stock.PlateHole] = [
    @stock.PlateHole::{ x_mm: 0.0, y_mm: 0.0, diameter_mm: 22.0, },
  ]
  let plate = match @stock.plate(60.0, 60.0, 5.0, holes~) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let motor = match @motors.nema_stepper_motor(frame, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(
    parent="hole-1",
    child="pilot",
    description="NEMA17 pilot in a plate bore",
  )
  let assembly = @assemblies.Assembly::new(name="motor-and-plate").add(
    plate,
    instance_name="plate",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("plate", motor, pair, instance_name="motor") {
    Ok(result) => result
    Err(e) => abort(e.message())
  }
  assert_eq(placed.count(), 2)
  // Plate hole frame is at z = -2.5; the motor pilot frame is at z = 40.
  assert_true(mate_near(alignment.placement.trans.2, -42.5))
  assert_true(alignment.axis_flipped)
  let (x0, x1, y0, y1, z0, z1) = placed.bounding_box()
  assert_true(x0 < -25.0 && x1 > 25.0)
  assert_true(y0 < -25.0 && y1 > 25.0)
  assert_true(z0 < -40.0 && z1 > 0.0)
}

///|
test "mate pair reports missing instances and connectors" {
  let part = match @fasteners.iso4032_nut(@standards.MetricSize::M4) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(parent="bore", child="shaft")
  let empty = @assemblies.Assembly::new(name="empty")
  match empty.add_mate_pair("nope", part, pair) {
    Err(@common.MatePairError::MissingInstance(name)) => assert_eq(name, "nope")
    _ => fail("expected missing instance")
  }
  let assembly = @assemblies.Assembly::new(name="one").add(
    part,
    instance_name="nut",
  )
  match assembly.add_mate_pair("nut", part, pair) {
    Err(@common.MatePairError::MissingConnector(name)) =>
      assert_eq(name, "shaft")
    _ => fail("expected missing connector")
  }
}
