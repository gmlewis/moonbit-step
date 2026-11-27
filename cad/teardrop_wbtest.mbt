///|
test "teardrop_profile_segments forms a valid closed 45-deg teardrop" {
  let segs = teardrop_profile_segments(2.0)
  assert_eq(segs.length(), 4)
  let prof = ExtrudedArcProfile::new(segs, 10.0)
  assert_true(prof.validate())
  // Area of circle (pi * r^2) + area of upper cap triangle (r^2 * (1 - pi/4)):
  // Exact 45-deg teardrop area = r^2 * (3*pi/4 + 1) = 4 * 3.35619449 = 13.424778
  // Volume for length 10 = 134.24778 mm^3.
  let expected_vol = 2.0 * 2.0 * (3.0 * @math.PI / 4.0 + 1.0) * 10.0
  assert_true((prof.volume() - expected_vol).abs() < 1.0e-4)
}

///|
test "horizontal_bore switches between Cylinder and teardrop" {
  let nom = horizontal_bore(1.7, 12.0, fdm=false, name="hole_nom")
  let fdm = horizontal_bore(1.7, 12.0, fdm=true, name="hole_fdm")
  let nom_step = Design::new(name="nom").add(nom).to_step_file()
  let fdm_step = Design::new(name="fdm").add(fdm).to_step_file()
  assert_true(nom_step.contains("CYLINDRICAL_SURFACE"))
  assert_true(fdm_step.contains("CYLINDRICAL_SURFACE"))
  assert_true(fdm_step.contains("PLANE"))
}
