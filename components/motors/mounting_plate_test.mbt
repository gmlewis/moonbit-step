///|
fn nema_plate_near(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
fn nema_plate_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  match part.connector(name) {
    Ok(connector) => connector
    Err(e) => abort(e.message())
  }
}

///|
test "NEMA mounting plate has the frame hole pattern and a pilot bore" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let plate = match @motors.nema_mounting_plate(frame, 60.0, 60.0, 6.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, z0, z1) = plate.bounding_box()
  assert_true(nema_plate_near(x0, -30.0) && nema_plate_near(x1, 30.0))
  assert_true(nema_plate_near(y0, -30.0) && nema_plate_near(y1, 30.0))
  assert_true(nema_plate_near(z0, -3.0) && nema_plate_near(z1, 3.0))
  let pilot = nema_plate_connector(plate, "pilot-bore")
  assert_true(pilot.kind is @common.MateKind::CylindricalBore)
  assert_true(nema_plate_near(pilot.placement.trans.2, -3.0))
  let hole = nema_plate_connector(plate, "bolt-hole-1")
  assert_true(
    nema_plate_near(hole.placement.trans.0, frame.bolt_spacing_mm / 2.0),
  )
  assert_true(
    nema_plate_near(hole.placement.trans.1, frame.bolt_spacing_mm / 2.0),
  )
  assert_true(plate.features().modeled.contains("nema-bolt-pattern"))
  assert_true(plate.features().omitted.length() > 0)
}

///|
test "NEMA motor pilot mates a mounting-plate pilot bore" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  let plate = match @motors.nema_mounting_plate(frame, 60.0, 60.0, 6.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let motor = match @motors.nema_stepper_motor(frame, 40.0) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let pair = @common.MatePair::new(parent="pilot-bore", child="pilot")
  let parent = nema_plate_connector(plate, "pilot-bore")
  let child = nema_plate_connector(motor, "pilot")
  let alignment = match pair.resolve(parent, child) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  // Plate bottom face is z = -3; motor pilot starts at z = 40.
  assert_true(nema_plate_near(alignment.placement.trans.2, -43.0))
  assert_true(alignment.axis_flipped)
}

///|
test "NEMA mounting plate rejects an undersized plate" {
  let frame = match @motors.nema_frame("NEMA17") {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_true(@motors.nema_mounting_plate(frame, 30.0, 30.0, 6.0) is Err(_))
  assert_true(@motors.nema_mounting_plate(frame, 60.0, 60.0, 0.0) is Err(_))
  assert_true(
    @motors.nema_mounting_plate(frame, 60.0, 60.0, 6.0, hole_clearance_mm=-1.0)
    is Err(_),
  )
}
