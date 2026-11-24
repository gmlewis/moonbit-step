///|
test "fastener pattern standard drill diameters match ISO / 3D-print specs" {
  assert_true(
    (@fasteners.heat_set_insert_pilot_diam_mm(@standards.M3) - 4.4).abs() <
    1.0e-9,
  )
  assert_true(
    (@fasteners.metric_clearance_hole_diam_mm(@standards.M3) - 3.4).abs() <
    1.0e-9,
  )
  assert_true(
    (@fasteners.metric_clearance_hole_diam_mm(@standards.M4) - 4.5).abs() <
    1.0e-9,
  )
  assert_true(
    (@fasteners.metric_tap_drill_diam_mm(@standards.M3) - 2.5).abs() < 1.0e-9,
  )
  assert_true(
    (@fasteners.metric_tap_drill_diam_mm(@standards.M4) - 3.3).abs() < 1.0e-9,
  )
}

///|
async test "HeatSetInsertPattern, BoltCirclePattern, and DowelPinPattern evaluate cleanly with OCCT" {
  let blank = @cad.Cylinder::new(30.0, 10.0).with_name("flange_plate")

  let inserts = @fasteners.HeatSetInsertPattern::rect(
    @standards.M3,
    width_mm=24.0,
    height_mm=24.0,
    depth_mm=6.0,
  )
  let with_inserts = inserts.cut_pockets_from(
    blank,
    z_mm=10.0,
    into_negative_z=true,
  )

  let bolts = @fasteners.BoltCirclePattern::ring(
    @standards.M4,
    count=4,
    bolt_circle_diam_mm=46.0,
    length_mm=12.0,
  )
  let with_bolts = bolts.cut_clearance_holes(
    with_inserts,
    z0_mm=0.0,
    depth_mm=10.0,
    counterbore_depth_mm=3.5,
  )

  let dowels = @fasteners.DowelPinPattern::ring(
    pin_diam_mm=6.0,
    count=2,
    bolt_circle_diam_mm=46.0,
    phase_deg=45.0,
  )
  let final_part = dowels.cut_pin_holes(with_bolts, z0_mm=0.0, depth_mm=10.0)

  if !@cad.csg_eval_available() {
    return
  }
  let step = @cad.Design::new(name="fastener-patterns-test")
    .add(final_part)
    .to_step_evaluated()
  assert_true(step.contains("ISO-10303-21;"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}

///|
test "pattern mate_connectors generate accurately positioned contact-plane mates" {
  let inserts = @fasteners.HeatSetInsertPattern::rect(
    @standards.M3,
    width_mm=32.0,
    height_mm=32.0,
    depth_mm=6.0,
  )
  let ins_mates = inserts.mate_connectors(z_mm=10.0)
  assert_eq(ins_mates.length(), 4)
  assert_eq(ins_mates[0].name, "insert_0")
  assert_eq(ins_mates[0].diameter_mm, Some(4.4))
  assert_eq(ins_mates[0].depth_mm, Some(6.0))

  let bolts = @fasteners.BoltCirclePattern::ring(
    @standards.M4,
    count=6,
    bolt_circle_diam_mm=34.0,
  )
  let bolt_mates = bolts.mate_connectors(z_mm=8.0, depth_mm=8.0)
  assert_eq(bolt_mates.length(), 6)
  assert_eq(bolt_mates[0].diameter_mm, Some(4.5))

  let dowels = @fasteners.DowelPinPattern::ring(
    pin_diam_mm=8.0,
    count=4,
    bolt_circle_diam_mm=38.0,
  )
  let dowel_mates = dowels.mate_connectors(z_mm=0.0)
  assert_eq(dowel_mates.length(), 4)
  assert_eq(dowel_mates[0].diameter_mm, Some(8.1))

  let p = @fasteners.AxialSnapPinParams::new().unwrap()
  let snap = @fasteners.AxialSnapFit::ring(p, count=3, bolt_circle_diam_mm=20.0)
  let m_mates = snap.male_connectors(z_mm=7.0)
  let f_mates = snap.female_connectors(z_mm=0.0)
  assert_eq(m_mates.length(), 3)
  assert_eq(f_mates.length(), 3)
  assert_eq(m_mates[0].axis, (0.0, 0.0, 1.0))
  assert_eq(f_mates[0].axis, (0.0, 0.0, -1.0))
}
