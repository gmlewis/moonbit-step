///|
test "goBILDA 1309 measured hub loops are valid profiles" {
  let outer = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_outer()),
    8.0,
  )
  assert_true(outer.validate())
  let void_loop = hub_loop(gobilda_sonic_hub_void())
  let flange = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_outer()),
    8.0,
    holes=[void_loop, @common.circle_loop(8.0, 8.0, 1.65)],
  )
  assert_true(flange.validate())
  assert_true(
    @cad.ExtrudedArcProfile::new(hub_loop(gobilda_sonic_hub_boss_a()), 2.0).validate(),
  )
  assert_true(
    @cad.ExtrudedArcProfile::new(hub_loop(gobilda_sonic_hub_boss_b()), 2.0).validate(),
  )
}

///|
test "goBILDA 1309 measured hub loop areas match the vendor sections" {
  let outer = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_outer()),
    1.0,
  )
  assert_true((outer.volume() - 618.422).abs() < 0.01)
  let boss_a = @cad.ExtrudedArcProfile::new(
    hub_loop(gobilda_sonic_hub_boss_a()),
    1.0,
  )
  assert_true((boss_a.volume() - 52.432).abs() < 0.01)
}
