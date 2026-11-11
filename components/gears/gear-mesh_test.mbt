///|
/// 2D gear-mesh interference tests.
///
/// A single static pose is not evidence that a gear pair can rotate. These
/// tests sample one complete mesh cycle: the driver rotates by one angular
/// pitch while the driven gear rotates at the kinematic ratio. Any proper
/// crossing between the two tooth outlines is a tooth interference.

//|
fn mesh_rotate(p : @cad.Vec2, angle_rad : Double) -> @cad.Vec2 {
  let c = @math.cos(angle_rad)
  let s = @math.sin(angle_rad)
  (c * p.0 - s * p.1, s * p.0 + c * p.1)
}

//|

///|
fn mesh_edge_crosses(
  a0 : @cad.Vec2,
  a1 : @cad.Vec2,
  b0 : @cad.Vec2,
  b1 : @cad.Vec2,
) -> Bool {
  let o1 = (a1.0 - a0.0) * (b0.1 - a0.1) - (a1.1 - a0.1) * (b0.0 - a0.0)
  let o2 = (a1.0 - a0.0) * (b1.1 - a0.1) - (a1.1 - a0.1) * (b1.0 - a0.0)
  let o3 = (b1.0 - b0.0) * (a0.1 - b0.1) - (b1.1 - b0.1) * (a0.0 - b0.0)
  let o4 = (b1.0 - b0.0) * (a1.1 - b0.1) - (b1.1 - b0.1) * (a1.0 - b0.0)
  // Strict interior crossing only: endpoint contact at the pitch point is not
  // interference, but a real flank overlap produces a proper crossing.
  let eps = 1.0e-9
  o1 * o2 < -eps && o3 * o4 < -eps
}

//|

///|
fn in_mesh_zone(p : @cad.Vec2, pitch_radius : Double) -> Bool {
  let x_ok = p.0 > pitch_radius - 4.0 && p.0 < pitch_radius + 6.0
  let y_ok = p.1.abs() < 8.0
  x_ok && y_ok
}

//|

///|
fn mesh_zone_edges(
  outline : Array[@cad.Vec2],
  pitch_radius : Double,
) -> Array[(@cad.Vec2, @cad.Vec2)] {
  let edges : Array[(@cad.Vec2, @cad.Vec2)] = []
  let n = outline.length()
  for i in 0..<n {
    let a = outline[i]
    let b = outline[(i + 1) % n]
    if in_mesh_zone(a, pitch_radius) || in_mesh_zone(b, pitch_radius) {
      edges.push((a, b))
    }
  }
  edges
}

///|
test "external gear pair has no tooth interference through a mesh cycle" {
  let module_mm = 2.0
  let driver_teeth = 20
  let driven_teeth = 40
  let pressure_angle = 20.0
  let driver = @gears.external_involute_outline(
    module_mm, driver_teeth, pressure_angle,
  )
  let driven = @gears.external_involute_outline(
    module_mm, driven_teeth, pressure_angle,
  )
  let pitch_driver = module_mm * driver_teeth.to_double() / 2.0
  let pitch_driven = module_mm * driven_teeth.to_double() / 2.0
  let center = pitch_driver + pitch_driven + 0.05
  let phase_deg = 180.0 + 180.0 / driven_teeth.to_double()
  let steps = 16
  let mut crossings = 0
  for step in 0..<steps {
    let driver_angle = 360.0 *
      step.to_double() /
      (driver_teeth.to_double() * steps.to_double())
    let driven_angle = -(driver_angle *
      driver_teeth.to_double() /
      driven_teeth.to_double())
    let da = driver_angle * @math.PI / 180.0
    let dda = (phase_deg + driven_angle) * @math.PI / 180.0
    let driver_edges = mesh_zone_edges(
      driver.map(fn(p) { mesh_rotate(p, da) }),
      pitch_driver,
    )
    let driven_edges = mesh_zone_edges(
      driven.map(fn(p) {
        let r = mesh_rotate(p, dda)
        (r.0 + center, r.1)
      }),
      pitch_driven,
    )
    for (a0, a1) in driver_edges {
      for (b0, b1) in driven_edges {
        if mesh_edge_crosses(a0, a1, b0, b1) {
          crossings = crossings + 1
        }
      }
    }
  }
  if crossings > 0 {
    abort(
      "gear pair tooth outlines cross " +
      crossings.to_string() +
      " times during one mesh cycle",
    )
  }
  assert_eq(crossings, 0)
}

//|

///|
fn near_mesh_point(p : @cad.Vec2, mesh : @cad.Vec2, radius : Double) -> Bool {
  let dx = p.0 - mesh.0
  let dy = p.1 - mesh.1
  dx * dx + dy * dy < radius * radius
}

//|

///|
fn edges_near(
  outline : Array[@cad.Vec2],
  mesh : @cad.Vec2,
  radius : Double,
) -> Array[(@cad.Vec2, @cad.Vec2)] {
  let edges : Array[(@cad.Vec2, @cad.Vec2)] = []
  let n = outline.length()
  for i in 0..<n {
    let a = outline[i]
    let b = outline[(i + 1) % n]
    if near_mesh_point(a, mesh, radius) || near_mesh_point(b, mesh, radius) {
      edges.push((a, b))
    }
  }
  edges
}

//|

///|
fn mesh_crossings(
  a_edges : Array[(@cad.Vec2, @cad.Vec2)],
  b_edges : Array[(@cad.Vec2, @cad.Vec2)],
) -> Int32 {
  let mut crossings = 0
  for (a0, a1) in a_edges {
    for (b0, b1) in b_edges {
      if mesh_edge_crosses(a0, a1, b0, b1) {
        crossings = crossings + 1
      }
    }
  }
  crossings
}

///|
test "planetary sun-planet phases mesh for a non-divisible layout" {
  // (18 + 42) % 5 == 0, but the sun tooth phase differs at each planet angle.
  // A single shared planet orientation is therefore not generally correct.
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=18,
      planet_teeth=12,
      planet_count=5,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let sun = @gears.external_involute_outline(2.0, 18, 20.0)
  let planet = @gears.external_involute_outline(2.0, 12, 20.0)
  let sun_radius = 2.0 * 18.0 / 2.0
  let planet_radius = 2.0 * 12.0 / 2.0
  let mut total = 0
  for item in set.items() {
    if item.instance_name.has_prefix("planet-") {
      let planet_world = planet.map(fn(p) {
        let q = item.placement.apply_point((p.0, p.1, 0.0))
        (q.0, q.1)
      })
      let cx = item.placement.trans.0
      let cy = item.placement.trans.1
      let r = Double::sqrt(cx * cx + cy * cy)
      let mesh = (sun_radius * cx / r, sun_radius * cy / r)
      let sun_edges = edges_near(sun, mesh, 6.0)
      let planet_edges = edges_near(planet_world, mesh, 6.0)
      total = total + mesh_crossings(sun_edges, planet_edges)
    }
  }
  assert_eq(total, 0)
  // Planet-planet tip clearance: adjacent centres are 2*C*sin(pi/P) apart.
  let center = params.center_distance()
  let adjacent = 2.0 * center * @math.sin(@math.PI / 5.0)
  let planet_tip = planet_radius + 2.0
  assert_true(adjacent > 2.0 * planet_tip)
}

//|

///|
fn in_radial_band(p : @cad.Vec2, r_min : Double, r_max : Double) -> Bool {
  let r2 = p.0 * p.0 + p.1 * p.1
  r2 > r_min * r_min && r2 < r_max * r_max
}

//|

///|
fn edges_in_band(
  outline : Array[@cad.Vec2],
  r_min : Double,
  r_max : Double,
) -> Array[(@cad.Vec2, @cad.Vec2)] {
  let edges : Array[(@cad.Vec2, @cad.Vec2)] = []
  let n = outline.length()
  for i in 0..<n {
    let a = outline[i]
    let b = outline[(i + 1) % n]
    if in_radial_band(a, r_min, r_max) || in_radial_band(b, r_min, r_max) {
      edges.push((a, b))
    }
  }
  edges
}

///|
test "standard planetary planets clear the approximate ring gear" {
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=12,
      planet_teeth=12,
      planet_count=3,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let planet = @gears.external_involute_outline(2.0, 12, 20.0)
  let ring = @gears.internal_ring_gear_profile(2.0, 36)
  let ring_edges = edges_in_band(ring, 30.0, 40.0)
  let mut total = 0
  for item in set.items() {
    if item.instance_name.has_prefix("planet-") {
      let world = planet.map(fn(p) {
        let q = item.placement.apply_point((p.0, p.1, 0.0))
        (q.0, q.1)
      })
      let planet_edges = edges_in_band(world, 28.0, 40.0)
      total = total + mesh_crossings(ring_edges, planet_edges)
    }
  }
  if total > 0 {
    abort("planet/ring outline crossings: " + total.to_string())
  }
  assert_eq(total, 0)
}

///|
/// rotate_outline rotates every point of an outline about the origin.
fn rotate_outline(
  outline : Array[@cad.Vec2],
  angle_deg : Double,
) -> Array[@cad.Vec2] {
  let rad = angle_deg * @math.PI / 180.0
  outline.map(fn(p) { mesh_rotate(p, rad) })
}

///|
test "sun and planet have no interference through a full mesh cycle" {
  let module_mm = 2.0
  let sun_teeth = 12
  let planet_teeth = 12
  let params = match
    @gears.PlanetaryParams::new(
      module_mm~,
      sun_teeth~,
      planet_teeth~,
      planet_count=3,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let sun = @gears.external_involute_outline(2.0, 12, 20.0)
  let planet = @gears.external_involute_outline(2.0, 12, 20.0)
  let sun_radius = 2.0 * 12.0 / 2.0
  let steps = 16
  let mut total = 0
  for item in set.items() {
    if item.instance_name.has_prefix("planet-") {
      let cx = item.placement.trans.0
      let cy = item.placement.trans.1
      let r = Double::sqrt(cx * cx + cy * cy)
      let mesh = (sun_radius * cx / r, sun_radius * cy / r)
      for step in 0..<steps {
        let sun_angle = 360.0 *
          step.to_double() /
          (sun_teeth.to_double() * steps.to_double())
        let planet_angle = -sun_angle *
          sun_teeth.to_double() /
          planet_teeth.to_double()
        let sun_world = rotate_outline(sun, sun_angle)
        let placement = @common.Placement::compose(
          item.placement,
          @common.Placement::rotation_z(planet_angle),
        )
        let world = planet.map(fn(p) {
          let q = placement.apply_point((p.0, p.1, 0.0))
          (q.0, q.1)
        })
        let sun_edges = edges_near(sun_world, mesh, 6.0)
        let planet_edges = edges_near(world, mesh, 6.0)
        total = total + mesh_crossings(sun_edges, planet_edges)
      }
    }
  }
  if total > 0 {
    abort("sun/planet crossings through a cycle: " + total.to_string())
  }
  assert_eq(total, 0)
}

///|
test "odd planet tooth count gets a half-pitch ring offset" {
  // Sun 18 / planet 11 / ring 40 is a valid set, but the planet's sun-side and
  // ring-side tooth phases differ by half a planet pitch. The ring must be
  // rotated by half a ring pitch; without it the static pose has ring/planet
  // tooth-on-tooth crossings.
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=18,
      planet_teeth=11,
      planet_count=2,
      face_width_mm=10.0,
    ) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let set = match @gears.planetary_gear_set(params) {
    Ok(a) => a
    Err(e) => abort(e.message())
  }
  let planet = @gears.external_involute_outline(2.0, 11, 20.0, backlash_mm=0.1)
  let ring = match
    @gears.internal_involute_ring_profile(2.0, 40, 20.0, backlash_mm=0.1) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let sun = @gears.external_involute_outline(2.0, 18, 20.0, backlash_mm=0.1)
  let mut ring_world = ring
  for item in set.items() {
    if item.instance_name == "ring" {
      ring_world = ring.map(fn(p) {
        let q = item.placement.apply_point((p.0, p.1, 0.0))
        (q.0, q.1)
      })
    }
  }
  let mut ring_crossings = 0
  let mut unphased_crossings = 0
  let mut sun_crossings = 0
  for item in set.items() {
    if item.instance_name.has_prefix("planet-") {
      let cx = item.placement.trans.0
      let cy = item.placement.trans.1
      let theta = @math.atan2(cy, cx)
      let mesh = (40.0 * @math.cos(theta), 40.0 * @math.sin(theta))
      let sun_mesh = (18.0 * @math.cos(theta), 18.0 * @math.sin(theta))
      let world = planet.map(fn(p) {
        let q = item.placement.apply_point((p.0, p.1, 0.0))
        (q.0, q.1)
      })
      let planet_edges = edges_near(world, mesh, 8.0)
      ring_crossings = ring_crossings +
        mesh_crossings(edges_near(ring_world, mesh, 8.0), planet_edges)
      // Negative control: the unrotated ring must cross, so the zero above is
      // not vacuous.
      unphased_crossings = unphased_crossings +
        mesh_crossings(edges_near(ring, mesh, 8.0), planet_edges)
      sun_crossings = sun_crossings +
        mesh_crossings(
          edges_near(sun, sun_mesh, 6.0),
          edges_near(world, sun_mesh, 6.0),
        )
    }
  }
  assert_eq(ring_crossings, 0)
  assert_eq(sun_crossings, 0)
  assert_true(unphased_crossings > 0)
  // The public cycle diagnostic must agree with the assembly.
  let cycle = match
    @gears.internal_mesh_interference(
      2.0,
      40,
      11,
      20.0,
      backlash_mm=0.1,
      phases=32,
    ) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_eq(cycle, 0)
}

///|
test "planetary rejects overlapping planets" {
  // 18/18/6 satisfies (sun + ring) % count == 0 but adjacent planet tips
  // overlap by 4 mm.
  assert_true(
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=18,
      planet_teeth=18,
      planet_count=6,
      face_width_mm=10.0,
    )
    is Err(_),
  )
  // A near-limit but valid set: chord 35.27 mm, tip diameter 28 mm.
  assert_true(
    @gears.PlanetaryParams::new(
      module_mm=2.0,
      sun_teeth=18,
      planet_teeth=12,
      planet_count=5,
      face_width_mm=10.0,
    )
    is Ok(_),
  )
}

///|
test "external gear rejects a backlash that closes the tooth" {
  assert_true(
    @gears.SpurGearParams::new(module_mm=2.0, teeth=20, backlash_mm=3.2)
    is Err(_),
  )
  assert_true(
    @gears.SpurGearParams::new(module_mm=2.0, teeth=20, backlash_mm=3.0)
    is Ok(_),
  )
}

///|
test "low-tooth gear records the undercut limitation" {
  let low = match @gears.SpurGearParams::new(module_mm=2.0, teeth=12) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let low_gear = match @gears.spur_gear(low) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let reason = low_gear.features().omission_reason("undercut")
  assert_true(reason is Some(_))
  let high = match @gears.SpurGearParams::new(module_mm=2.0, teeth=20) {
    Ok(p) => p
    Err(e) => abort(e.message())
  }
  let high_gear = match @gears.spur_gear(high) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  assert_true(high_gear.features().omission_reason("undercut") is Some(_))
}
