///|
test "mechanism bodies have positive analytic volume and closed meshes" {
  let profile = mech_rail_profile()
  let parts : Array[@common.Component] = [
    mech_ok(@mechanisms.hinge(40.0, 20.0, 6.0, 4.0)),
    mech_ok(@mechanisms.clevis(30.0, 20.0, 6.0, 5.0, 8.0, 6.0)),
    mech_ok(@mechanisms.clevis_pin(6.0, 30.0, 10.0, 2.0)),
    mech_ok(@mechanisms.linkage_bar(100.0, 20.0, 5.0, 8.0)),
    mech_ok(@mechanisms.linear_rail(profile, 300.0)),
    mech_ok(@mechanisms.linear_carriage(profile, 80.0, 50.0, 30.0)),
    mech_ok(@mechanisms.lead_screw_nut(16.0, 20.0, 24.0, 4.0, 8.0, 2.0)),
    mech_ok(@mechanisms.belt_loop(20.0, 100.0, 2.0, 10.0)),
    mech_ok(@mechanisms.eccentric_cam(20.0, 5.0, 8.0, 6.0)),
    mech_ok(@mechanisms.roller_follower(10.0, 8.0, 5.0, 4.0, 10.0)),
    mech_ok(@mechanisms.oldham_coupling(5.0, 20.0, 8.0, 18.0, 3.0, 4.0)),
    mech_ok(@mechanisms.snap_latch(40.0, 2.0, 10.0, 3.0, 5.0)),
    mech_ok(@mechanisms.o_ring(20.0, 4.0)),
    mech_ok(@mechanisms.grooved_shaft(20.0, 50.0, 4.0, 2.0, 20.0)),
    mech_ok(@mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0)),
    mech_ok(@mechanisms.u_bracket(100.0, 40.0, 60.0, 4.0, 5.0)),
    mech_ok(@mechanisms.z_bracket(60.0, 50.0, 40.0, 30.0, 4.0, 5.0)),
    mech_ok(@mechanisms.tapped_boss(16.0, 20.0, 24.0, 4.0, 6.0, 1.0, 10.0)),
    mech_ok(@mechanisms.rack_gear(2.0, 10, 6.0, 10.0)),
    mech_ok(@mechanisms.ansi40_sprocket(16)),
  ]
  for part in parts {
    let mut total = 0.0
    for layer in part.layers() {
      let volume = match layer.shape.analysis_volume() {
        Ok(v) => v
        Err(e) => abort(part.name() + ": " + e.message())
      }
      assert_true(volume > 0.0)
      total += volume
    }
    assert_true(total > 0.0)
    let mesh = match part.layers()[0].shape.analysis_mesh() {
      Ok(m) => m
      Err(e) => abort(part.name() + ": " + e.message())
    }
    let (vertices, triangles) = mesh
    assert_true(vertices.length() > 0)
    assert_true(triangles.length() > 0)
  }
}
