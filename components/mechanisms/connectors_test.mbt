///|
fn mech_has_connector(part : @common.Component, name : String) -> Bool {
  for connector in part.connectors() {
    if connector.name == name {
      return true
    }
  }
  false
}

///|
fn mech_connector(
  part : @common.Component,
  name : String,
) -> @common.MateConnector {
  for connector in part.connectors() {
    if connector.name == name {
      return connector
    }
  }
  abort("missing connector " + name)
}

///|
fn mech_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn mech_close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-6
}

///|
fn mech_rail_profile() -> @mechanisms.LinearRailProfile {
  match
    @mechanisms.linear_rail_profile(
      width_mm=20.0,
      height_mm=15.0,
      groove_width_mm=6.0,
      groove_depth_mm=2.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
}

///|
test "every public mechanism builder exposes a connector" {
  let profile = mech_rail_profile()
  let builders : Array[(@common.Component, String)] = [
    (mech_ok(@mechanisms.hinge(40.0, 20.0, 6.0, 4.0)), "hinge-axis"),
    (mech_ok(@mechanisms.clevis(30.0, 20.0, 6.0, 5.0, 8.0, 6.0)), "pin-bore-a"),
    (mech_ok(@mechanisms.clevis_pin(6.0, 30.0, 10.0, 2.0)), "shaft-end"),
    (mech_ok(@mechanisms.rod_end(20.0, 6.0, 8.0, 8.0, 30.0)), "eye-bore"),
    (mech_ok(@mechanisms.linkage_bar(100.0, 20.0, 5.0, 8.0)), "pivot-a"),
    (mech_ok(@mechanisms.linear_rail(profile, 300.0)), "rail-axis"),
    (
      mech_ok(@mechanisms.linear_carriage(profile, 80.0, 50.0, 30.0)),
      "block-face",
    ),
    (mech_ok(@mechanisms.lead_screw(8.0, 200.0)), "thread"),
    (
      mech_ok(@mechanisms.lead_screw_nut(16.0, 20.0, 24.0, 4.0, 8.0, 2.0)),
      "flange-face",
    ),
    (mech_ok(@mechanisms.belt_loop(20.0, 100.0, 2.0, 10.0)), "pulley-a"),
    (
      mech_ok(@mechanisms.belt_loop_unequal(20.0, 40.0, 100.0, 2.0, 10.0)),
      "pulley-b",
    ),
    (mech_ok(@mechanisms.eccentric_cam(20.0, 5.0, 8.0, 6.0)), "rotation-bore"),
    (
      mech_ok(@mechanisms.roller_follower(10.0, 8.0, 5.0, 4.0, 10.0)),
      "roller-surface",
    ),
    (
      mech_ok(@mechanisms.oldham_coupling(5.0, 20.0, 8.0, 30.0, 4.0, 6.0)),
      "bore-a",
    ),
    (mech_ok(@mechanisms.extension_spring(20.0, 2.0, 40.0, 8)), "hook-leg-a"),
    (mech_ok(@mechanisms.torsion_spring(20.0, 2.0, 40.0, 8)), "leg-a"),
    (mech_ok(@mechanisms.snap_latch(40.0, 2.0, 10.0, 3.0, 5.0)), "root-face"),
    (mech_ok(@mechanisms.o_ring(20.0, 4.0)), "torus-axis"),
    (
      mech_ok(@mechanisms.grooved_shaft(20.0, 50.0, 4.0, 2.0, 20.0)),
      "groove-seat",
    ),
    (mech_ok(@mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0)), "base-hole-1"),
    (
      mech_ok(@mechanisms.u_bracket(100.0, 40.0, 60.0, 4.0, 5.0)),
      "wall-hole-a-1",
    ),
    (
      mech_ok(@mechanisms.tapped_boss(16.0, 20.0, 24.0, 4.0, 6.0, 1.0, 10.0)),
      "thread",
    ),
    (mech_ok(@mechanisms.rack_gear(2.0, 10, 6.0, 10.0)), "pitch-plane"),
  ]
  for entry in builders {
    let (part, expected) = entry
    if part.connectors().length() == 0 {
      abort("builder produced no connector: " + part.name())
    }
    if !mech_has_connector(part, expected) {
      abort("builder " + part.name() + " is missing connector " + expected)
    }
  }
}
