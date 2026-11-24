///|
test "SplitRingPlanetaryParams ratios match exact Wolfrom formula" {
  let d = @planetary.SplitRingPlanetaryParams::default()
  // 20/14-48 / 18-52 -> (1 + 48/20) / (1 - (48*18)/(14*52)) = -18.2
  assert_true((d.ratio() + 18.2).abs() < 1.0e-9)

  let m51 = @planetary.SplitRingPlanetaryParams::manafish_51()
  // 12/18-48 / 21-51 -> -51:1
  assert_true((m51.ratio() + 51.0).abs() < 1.0e-9)
}

///|
test "SplitRingPlanetaryParams rejects invalid center distance, meshing, or planet collision" {
  // Mismatched center distance: 48 - 14 = 34 != 53 - 18 = 35
  assert_true(
    @planetary.SplitRingPlanetaryParams::new(ring2_teeth=53) is Err(_),
  )
  // Bad stage 1 ring: 20 + 2*14 = 48 != 50
  assert_true(
    @planetary.SplitRingPlanetaryParams::new(ring1_teeth=50) is Err(_),
  )
  // Degenerate identical stages
  assert_true(
    @planetary.SplitRingPlanetaryParams::new(planet2_teeth=14, ring2_teeth=48)
    is Err(_),
  )
  // Colliding adjacent upper planets (4 planets of 20T on 17.5 mm orbit)
  assert_true(
    @planetary.SplitRingPlanetaryParams::new(
      sun_teeth=12,
      planet1_teeth=16,
      ring1_teeth=44,
      planet2_teeth=20,
      ring2_teeth=48,
      planet_count=4,
    )
    is Err(_),
  )
}

///|
test "split_ring_planetary_layout matches orbit radius and outer diameter" {
  let params = @planetary.SplitRingPlanetaryParams::default()
  let layout = @planetary.split_ring_planetary_layout(params)
  assert_true(
    (layout.stage1.center_distance_mm - layout.stage2.center_distance_mm).abs() <
    1.0e-9,
  )
  assert_true(
    (layout.stage1.ring_outer_radius_mm - layout.stage2.ring_outer_radius_mm).abs() <
    1.0e-6,
  )
  assert_true(layout.planets_identical)
  assert_eq(layout.planet_centers_xy.length(), 4)
  assert_true(layout.snap_bcd_mm > 0.0)
  assert_true((layout.total_length_mm - 20.5).abs() < 1.0e-9)
}

///|
test "split_ring_planetary_gearbox exposes all layers and contact-plane mates" {
  let params = @planetary.SplitRingPlanetaryParams::default()
  let comp = @planetary.split_ring_planetary_gearbox(params).unwrap()
  // Stage 1: sun + 4 planets + ring1 = 6; Stage 2: 4 planets + ring2 = 5 -> 11 layers
  assert_eq(comp.layers().length(), 11)
  assert_true(comp.connector("input-face") is Ok(_))
  assert_true(comp.connector("sun-bore") is Ok(_))
  assert_true(comp.connector("snap-mating-plane") is Ok(_))
  assert_true(comp.connector("output-face") is Ok(_))
  assert_true(comp.connector("fixed-ring-outer-seat") is Ok(_))
  assert_true(comp.connector("output-ring-outer-seat") is Ok(_))
}

///|
test "split_ring_exploded_design floats Cartridge 2 coaxially above Cartridge 1" {
  let params = @planetary.SplitRingPlanetaryParams::default()
  let exploded = @planetary.split_ring_exploded_design(params, gap_mm=25.0).unwrap()
  assert_eq(exploded.nodes.length(), 11)
  // Upper ring (last node) should start at stage1_length + gap + explode_gap = 35.5 mm
  let upper_ring = exploded.nodes[10]
  assert_true((upper_ring.tz - 35.5).abs() < 1.0e-6)
}

///|
async test "split-ring cartridges evaluate cleanly with OCCT" {
  let params = @planetary.SplitRingPlanetaryParams::new(
    num_elbows=0,
    resolution=4,
    snap_pins_per_planet=2,
  ).unwrap()
  let lower = @planetary.split_ring_lower_cartridge_design(params).unwrap()
  let upper = @planetary.split_ring_upper_cartridge_design(params).unwrap()
  assert_eq(lower.nodes.length(), 6)
  assert_eq(upper.nodes.length(), 5)
  if !@cad.csg_eval_available() {
    return
  }
  let lower_step = lower.to_step_evaluated()
  assert_true(lower_step.contains("MANIFOLD_SOLID_BREP"))
  let upper_step = upper.to_step_evaluated()
  assert_true(upper_step.contains("MANIFOLD_SOLID_BREP"))
}

///|
test "split-ring planets stay upright along +Z with zero sideways Y-tilt" {
  let params = @planetary.SplitRingPlanetaryParams::default()
  let lower = @planetary.split_ring_lower_cartridge_design(
    params,
    include_snap_pins=false,
  ).unwrap()
  // Nodes: [sun, p1, p2, p3, p4, ring1]
  for i in 1..<=4 {
    let (_, _, _, _, z0, z1) = lower.nodes[i].bounding_box()
    assert_true(z0.abs() < 0.6)
    assert_true(
      (z1 - (params.stage1_length_mm + params.ring_axial_gap_mm)).abs() < 0.6,
    )
  }
  let upper = @planetary.split_ring_upper_cartridge_design(
    params,
    include_snap_sockets=false,
  ).unwrap()
  // Nodes: [p1, p2, p3, p4, ring2]
  for i in 0..<4 {
    let (_, _, _, _, z0, z1) = upper.nodes[i].bounding_box()
    assert_true(z0.abs() < 0.1)
    assert_true((z1 - params.stage2_length_mm).abs() < 0.1)
  }
}
