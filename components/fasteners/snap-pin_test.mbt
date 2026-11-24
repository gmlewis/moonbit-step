///|
test "axial_snap_pin default params compute exact 45-deg dimensions" {
  let p = @fasteners.AxialSnapPinParams::new().unwrap()
  assert_true((p.head_radius_mm() - 2.8).abs() < 1.0e-9)
  assert_true((p.flare_height_mm() - 0.3).abs() < 1.0e-9)
  assert_true((p.lead_in_height_mm() - 1.0).abs() < 1.0e-9)
  assert_true((p.total_height_mm() - 5.3).abs() < 1.0e-9)
  assert_true((p.void_depth_mm() - 5.6).abs() < 1.0e-9)
  assert_eq(p.num_slots, 2)
}

///|
test "axial_snap_pin requires mandatory vertical flex slot" {
  assert_true(@fasteners.AxialSnapPinParams::new(num_slots=0) is Err(_))
  assert_true(@fasteners.AxialSnapPinParams::new(num_slots=-1) is Err(_))
  assert_true(@fasteners.AxialSnapPinParams::new(undercut_mm=0.0) is Err(_))
  assert_true(
    @fasteners.AxialSnapPinParams::new(neck_radius_mm=3.5, base_radius_mm=3.0)
    is Err(_),
  )
  assert_true(@fasteners.AxialSnapPinParams::new(tip_radius_mm=3.0) is Err(_))
}

///|
test "axial_snap_pin male and female components build with valid connectors" {
  let p = @fasteners.AxialSnapPinParams::new().unwrap()
  let male = @fasteners.axial_snap_pin_male(p)
  let female = @fasteners.axial_snap_pin_female_void(p)
  assert_true(male.connector("mating_face") is Ok(_))
  assert_true(male.connector("tip") is Ok(_))
  assert_true(female.connector("mating_face") is Ok(_))
  let pts = @fasteners.axial_snap_ring_positions(4, 12.0)
  assert_eq(pts.length(), 4)
  assert_true((pts[0].0 - 12.0).abs() < 1.0e-9)
  assert_true(pts[0].1.abs() < 1.0e-9)
  assert_true(pts[1].0.abs() < 1.0e-9)
  assert_true((pts[1].1 - 12.0).abs() < 1.0e-9)
}

///|
async test "axial_snap_pin male and female evaluate cleanly with OCCT" {
  let p = @fasteners.AxialSnapPinParams::new().unwrap()
  let male_design = @cad.Design::new(name="snap-male-test").add(
    @fasteners.axial_snap_pin_male_node(p),
  )
  let male_step = male_design.to_step_evaluated()
  assert_true(male_step.contains("ISO-10303-21;"))
  assert_true(male_step.contains("MANIFOLD_SOLID_BREP"))

  // Subtract female void from a mating gear disk and verify OCCT boolean succeeds.
  let disk = @cad.Cylinder::new(10.0, 8.0).with_name("mating_disk")
  let void_node = @fasteners.axial_snap_pin_female_void_node(p)
  let female_design = @cad.Design::new(name="snap-female-test").add(
    @cad.difference(disk, [void_node], name="mating_disk_with_socket"),
  )
  let female_step = female_design.to_step_evaluated()
  assert_true(female_step.contains("ISO-10303-21;"))
  assert_true(female_step.contains("MANIFOLD_SOLID_BREP"))
}

///|
async test "AxialSnapFit::join_pair builds matched male/female pair with zero loops" {
  let p = @fasteners.AxialSnapPinParams::new().unwrap()
  let snap = @fasteners.AxialSnapFit::ring(p, count=3, bolt_circle_diam_mm=20.0)
  assert_eq(snap.positions.length(), 3)
  let base = @cad.Cylinder::new(16.0, 7.0).with_name("base_gear")
  let mating = @cad.Cylinder::new(16.0, 7.0).with_name("mating_gear")
  let (male_gear, female_gear) = snap.join_pair(
    base,
    mating,
    base_z_mm=7.0,
    mating_z_mm=0.0,
  )
  let step = @cad.Design::new(name="snap-pair-test")
    .add(male_gear.translate(x=-20.0))
    .add(female_gear.translate(x=20.0))
    .to_step_evaluated()
  assert_true(step.contains("ISO-10303-21;"))
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}
