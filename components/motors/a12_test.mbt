///|
fn a12_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn a12_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
test "A12 8318 defaults match the measured envelope" {
  let spec = @motors.a12_motor_100kv_spec()
  assert_true(@motors.a12_motor_spec(spec) is Ok(_))
  let part = a12_ok(@motors.a12_motor_100kv())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  // 33 mm overall height: 4.5 mm prop adapter overhang plus 28.5 mm to the
  // rear mount face. The bell sets the 91 mm outside diameter.
  assert_true(a12_close(x0, -4.5))
  assert_true(a12_close(x1, 28.5))
  assert_true(a12_close(x1 - x0, 33.0))
  assert_true(a12_close(y0, -45.5))
  assert_true(a12_close(y1, 45.5))
  assert_true(a12_close(z0, -45.5))
  assert_true(a12_close(z1, 45.5))
  // 3 bell bodies + 42 magnets + adapter + lamination + 36 coils + plate +
  // bearing tube + insulator + shaft.
  assert_eq(part.layers().length(), 87)
  let names : Array[String] = part.layers().map(fn(layer) { layer.name })
  for
    name in [
      "bell-face", "bell-skirt", "bell-hub-boss", "prop-adapter", "stator-lamination",
      "stator-plate", "bearing-tube", "pcb-insulator", "shaft",
    ] {
    assert_true(names.contains(name))
  }
  for i in 1..<=42 {
    assert_true(names.contains("rotor-magnet-\{i}"))
  }
  for i in 1..<=36 {
    assert_true(names.contains("stator-coil-\{i}"))
  }
  assert_true(part.features().modeled.contains("bell-windows"))
  assert_true(part.features().modeled.contains("stator-windings"))
  assert_true(part.features().omission_reason("kv-and-performance") is Some(_))
  // The adapter uses one 23 mm circle for both the propeller holes and the
  // four countersunk adapter screws (45 degrees apart).
  assert_true(
    a12_close(
      spec.prop_screw_circle_diameter_mm,
      spec.prop_hole_circle_diameter_mm,
    ),
  )
}

///|
test "A12 exposes explicit rotor and stator connectors" {
  let part = a12_ok(@motors.a12_motor_100kv())
  for
    name in [
      "rotor-shaft-bell-side", "rotor-shaft-mount-side", "rotor-output-face", "stator-mount-face",
    ] {
    assert_true(part.connector(name) is Ok(_))
  }
  for i in 1..<=4 {
    assert_true(part.connector("rotor-output-hole-\{i}") is Ok(_))
    assert_true(part.connector("stator-mount-hole-m3-\{i}") is Ok(_))
    assert_true(part.connector("stator-mount-hole-m4-\{i}") is Ok(_))
  }
  let output_face = match part.connector("rotor-output-face") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(output_face.kind is @common.MateKind::PlaneFace)
  assert_true(a12_close(output_face.placement.trans.0, -4.5))
  assert_true(a12_close(output_face.diameter_mm.unwrap(), 29.0))
  assert_true(output_face.description.contains("ROTATING"))
  let mount_face = match part.connector("stator-mount-face") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(mount_face.kind is @common.MateKind::PlaneFace)
  assert_true(a12_close(mount_face.placement.trans.0, 28.5))
  assert_true(mount_face.description.contains("FIXED"))
  let m3 = match part.connector("stator-mount-hole-m3-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(a12_close(m3.diameter_mm.unwrap(), 3.4))
  assert_true(a12_close(m3.placement.trans.0, 28.5))
  assert_true(m3.axis.0 > 0.0)
  assert_true(m3.description.contains("FIXED"))
  let m4 = match part.connector("stator-mount-hole-m4-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(a12_close(m4.diameter_mm.unwrap(), 4.5))
  let output_hole = match part.connector("rotor-output-hole-1") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(output_hole.kind is @common.MateKind::CylindricalBore)
  assert_true(a12_close(output_hole.diameter_mm.unwrap(), 4.0))
  assert_true(output_hole.description.contains("ROTATING"))
  let shaft = match part.connector("rotor-shaft-mount-side") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(shaft.kind is @common.MateKind::CylindricalShaft)
  assert_true(a12_close(shaft.diameter_mm.unwrap(), 12.0))
  assert_true(shaft.description.contains("ROTATING"))
}

///|
test "A12 stator mount holes sit on the plate spokes" {
  let spec = @motors.a12_motor_100kv_spec()
  let pitch = 360.0 / spec.stator_plate_window_count.to_double()
  // Solid plate spokes are centred halfway between adjacent air openings.
  let spoke_phase = spec.stator_plate_window_phase_deg + pitch / 2.0
  let wrap = fn(angle : Double) -> Double {
    let m = angle % pitch
    if m < 0.0 {
      m + pitch
    } else {
      m
    }
  }
  let offsets : Array[Double] = []
  for i in 0..<spec.mount_m3_count {
    offsets.push(
      wrap(
        spec.mount_hole_phase_deg +
        360.0 * i.to_double() / spec.mount_m3_count.to_double() -
        spoke_phase,
      ),
    )
  }
  for i in 0..<spec.mount_m4_count {
    offsets.push(
      wrap(
        spec.mount_hole_phase_deg +
        45.0 +
        360.0 * i.to_double() / spec.mount_m4_count.to_double() -
        spoke_phase,
      ),
    )
  }
  for offset in offsets {
    assert_true(offset < 1.0e-6 || pitch - offset < 1.0e-6)
  }
}

///|
test "A12 STEP contains only analytic surfaces" {
  let part = a12_ok(@motors.a12_motor_100kv())
  let mut inventory = @cad.SurfaceInventory::empty()
  for layer in part.layers() {
    inventory = inventory.add(layer.shape.surface_inventory())
  }
  assert_eq(inventory.bspline, 0)
  assert_eq(inventory.swept, 0)
  assert_true(inventory.plane > 0)
  assert_true(inventory.cylinder > 0)
  assert_true(inventory.torus > 0)
  let step = part.to_step(checked=true)
  assert_false(step.contains("B_SPLINE_SURFACE"))
  assert_false(step.contains("TRIANGULATED_FACE"))
  assert_false(step.contains("FACE_BASED_SURFACE_MODEL"))
}

///|
test "A12 parameters can be overridden for a smaller motor" {
  let spec : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    bell_outer_diameter_mm: 72.0,
    bell_skirt_length_mm: 18.0,
    bell_window_outer_diameter_mm: 63.0,
    bell_window_corner_radius_mm: 2.0,
    magnet_outer_diameter_mm: 69.0,
    magnet_start_mm: 2.8,
    magnet_length_mm: 14.0,
    prop_adapter_diameter_mm: 26.0,
    stator_outer_diameter_mm: 64.0,
    stator_inner_diameter_mm: 50.0,
    stator_stack_length_mm: 14.0,
    stator_stack_start_mm: 3.8,
    stator_slot_floor_diameter_mm: 56.0,
    coil_radial_inner_diameter_mm: 56.4,
    coil_radial_outer_diameter_mm: 64.6,
    coil_width_mm: 4.4,
    stator_plate_diameter_mm: 48.0,
    stator_plate_start_mm: 17.8,
    stator_plate_window_inner_diameter_mm: 40.0,
    stator_plate_window_outer_diameter_mm: 46.0,
    stator_plate_window_corner_radius_mm: 1.0,
    bearing_tube_outer_diameter_mm: 20.0,
    pcb_ring_inner_diameter_mm: 40.0,
    pcb_ring_outer_diameter_mm: 46.0,
    shaft_diameter_mm: 10.0,
    prop_hole_circle_diameter_mm: 20.0,
    prop_screw_circle_diameter_mm: 20.0,
  }
  assert_true(@motors.a12_motor_spec(spec) is Ok(_))
  let part = a12_ok(@motors.a12_motor(spec))
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  // 1.0 boss + 3.5 adapter + 17.8 plate start + 5.7 plate thickness.
  assert_true(a12_close(x1 - x0, 28.0))
  assert_true(a12_close(y0, -36.0))
  assert_true(a12_close(y1, 36.0))
}

///|
test "A12 validation rejects impossible layouts" {
  let too_wide : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    bell_window_outer_half_angle_deg: 30.0,
  }
  assert_true(@motors.a12_motor_spec(too_wide) is Err(_))
  let magnets_too_large : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    magnet_outer_diameter_mm: 92.0,
  }
  assert_true(@motors.a12_motor_spec(magnets_too_large) is Err(_))
  let coils_overlap : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    coil_width_mm: 7.0,
  }
  assert_true(@motors.a12_motor_spec(coils_overlap) is Err(_))
  let holes_in_windows : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    stator_plate_window_inner_diameter_mm: 30.0,
  }
  assert_true(@motors.a12_motor_spec(holes_in_windows) is Err(_))
  let shaft_too_big : @motors.A12MotorSpec = {
    ..@motors.a12_motor_100kv_spec(),
    shaft_diameter_mm: 13.0,
  }
  assert_true(@motors.a12_motor_spec(shaft_too_big) is Err(_))
}
