///|
// Parametric herringbone planetary gearbox.
//
// Ported from `examples/38-planetary-gearbox` (the Blackjack `HerringboneGear`
// algorithm): a sun gear, N equally spaced planet gears, and an inward-facing
// ring gear, all herringbone. `num_elbows = 0` builds straight gears with exact
// line/arc extrusions (the smooth planetary style); `num_elbows >= 1` builds the
// herringbone zig-zag with the same swept geometry and dimensions as the
// original generator, so printed parts line up.
//
// Every gear gets named mate connectors. The model exports in the print-flat
// Z-up frame by default; `y_up = true` keeps the native Y-up frame (gear axes
// along +Y).

///|
let hb_deg : Double = @math.PI / 180.0

///|
let hb_two_pi : Double = 2.0 * @math.PI

///|
/// Points along each involute flank in the swept outline.
const HB_INVOLUTE_POINTS : Int32 = 20

///|
/// Maximum profile rotation between adjacent swept cross-sections.
const HB_MAX_SWEEP_STEP_DEG : Double = 24.0

///|
/// HerringbonePlanetaryParams is a validated gearbox request. Every option from
/// the original generator is kept as a parameter.
pub(all) struct HerringbonePlanetaryParams {
  module_mm : Double
  gear_length_mm : Double
  helix_angle_deg : Double
  pressure_angle_deg : Double
  num_elbows : Int32
  resolution : Int32
  hole_type : String
  hole_radius_mm : Double
  tolerance_mm : Double
  outer_thickness_mm : Double
  sun_teeth : Int32
  planet_count : Int32
  planet_teeth : Int32
  ring_teeth : Int32
}

///|
/// HerringbonePlanetaryParams::new validates a gearbox request and resolves the
/// planet tooth count (0 = same as the sun) and ring tooth count (0 = sun +
/// 2*planet).
pub fn HerringbonePlanetaryParams::new(
  module_mm~ : Double,
  gear_length_mm~ : Double,
  helix_angle_deg~ : Double = 30.0,
  pressure_angle_deg~ : Double = 20.0,
  num_elbows~ : Int32 = 4,
  resolution~ : Int32 = 9,
  hole_type~ : String = "None",
  hole_radius_mm~ : Double = 10.0,
  tolerance_mm~ : Double = 0.25,
  outer_thickness_mm~ : Double = 10.0,
  sun_teeth~ : Int32 = 12,
  planet_count~ : Int32 = 3,
  planet_teeth~ : Int32 = 0,
  ring_teeth~ : Int32 = 0,
) -> Result[HerringbonePlanetaryParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("--module must be > 0"))
  }
  if gear_length_mm <= 0.0 {
    return Err(@common.InvalidParameter("--gearLength must be > 0"))
  }
  if sun_teeth < 6 {
    return Err(
      @common.InvalidParameter(
        "--numTeeth must be >= 6 (HerringboneGear minimum)",
      ),
    )
  }
  if num_elbows < 0 {
    return Err(@common.InvalidParameter("--numElbows must be >= 0"))
  }
  if resolution < 1 {
    return Err(@common.InvalidParameter("--resolution must be >= 1"))
  }
  if planet_count < 1 {
    return Err(@common.InvalidParameter("--numPlanets must be >= 1"))
  }
  if pressure_angle_deg < 1.0 {
    return Err(@common.InvalidParameter("--pressureAngle must be >= 1"))
  }
  if tolerance_mm < 0.0 {
    return Err(@common.InvalidParameter("--tolerance must be >= 0"))
  }
  if outer_thickness_mm <= 0.0 {
    return Err(@common.InvalidParameter("--outerThickness must be > 0"))
  }
  if hole_type == "Hollow" {
    return Err(
      @common.InvalidParameter(
        "--holeType=Hollow is an open shell and cannot be written as a solid STEP body; use None, Squared, Hexagonal, Octagonal or Circular",
      ),
    )
  }
  let resolved_planet = if planet_teeth == 0 { sun_teeth } else { planet_teeth }
  if resolved_planet < 6 {
    return Err(
      @common.InvalidParameter(
        "--planetTeeth must be >= 6 (or 0 to use --numTeeth)",
      ),
    )
  }
  let resolved_ring = if ring_teeth == 0 {
    sun_teeth + 2 * resolved_planet
  } else {
    ring_teeth
  }
  if resolved_ring != sun_teeth + 2 * resolved_planet {
    return Err(
      @common.InvalidParameter(
        "--ringTeeth must equal --numTeeth + 2*--planetTeeth for a standard internal mesh",
      ),
    )
  }
  if (sun_teeth + resolved_ring) % planet_count != 0 {
    return Err(
      @common.InvalidParameter(
        "tooth counts cannot be equally spaced in --numPlanets positions: (sun+ring) must be divisible by --numPlanets",
      ),
    )
  }
  let sun = hb_gear_dims(module_mm, pressure_angle_deg * hb_deg, sun_teeth)
  let planet = hb_gear_dims(
    module_mm,
    pressure_angle_deg * hb_deg,
    resolved_planet,
  )
  if hole_type != "None" {
    if hole_radius_mm >= sun.root_radius_mm ||
      hole_radius_mm >= planet.root_radius_mm {
      return Err(
        @common.InvalidDimension(
          "--holeRadius must be less than the gear root radius",
        ),
      )
    }
  }
  Ok({
    module_mm,
    gear_length_mm,
    helix_angle_deg,
    pressure_angle_deg,
    num_elbows,
    resolution,
    hole_type,
    hole_radius_mm,
    tolerance_mm,
    outer_thickness_mm,
    sun_teeth,
    planet_count,
    planet_teeth: resolved_planet,
    ring_teeth: resolved_ring,
  })
}

///|
/// HerringboneGearDims is the radii of one gear.
pub(all) struct HerringboneGearDims {
  num_teeth : Int32
  pitch_radius_mm : Double
  base_radius_mm : Double
  root_radius_mm : Double
  outer_radius_mm : Double
}

///|
/// HerringbonePlanetPlacement is one planet's native-frame position and
/// rotation.
pub(all) struct HerringbonePlanetPlacement {
  x : Double
  z : Double
  phi_deg : Double
}

///|
/// HerringbonePlanetaryLayout is the derived, printable layout.
pub(all) struct HerringbonePlanetaryLayout {
  module_mm : Double
  gear_length_mm : Double
  helix_angle_deg : Double
  helix_angle_sun_deg : Double
  pressure_angle_deg : Double
  num_elbows : Int32
  resolution : Int32
  hole_type : String
  hole_radius_mm : Double
  tolerance_mm : Double
  outer_thickness_mm : Double
  sun : HerringboneGearDims
  planet : HerringboneGearDims
  ring : HerringboneGearDims
  ring_teeth : Int32
  center_distance_mm : Double
  center_delta_mm : Double
  ring_outer_radius_mm : Double
  sun_direction : Double
  planet_direction : Double
  planets : Array[HerringbonePlanetPlacement]
}

///|
/// herringbone_planetary_layout derives the layout for validated params.
pub fn herringbone_planetary_layout(
  params : HerringbonePlanetaryParams,
) -> HerringbonePlanetaryLayout {
  let p = params
  let module_mm = p.module_mm
  let pa = p.pressure_angle_deg * hb_deg
  let ha = hb_clamp(p.helix_angle_deg, 0.0, 45.0) * hb_deg
  let sun = hb_gear_dims(module_mm, pa, p.sun_teeth)
  let planet = hb_gear_dims(module_mm, pa, p.planet_teeth)
  let ring_nominal = hb_gear_dims(module_mm, pa, p.ring_teeth)
  let ring : HerringboneGearDims = {
    ..ring_nominal,
    root_radius_mm: ring_nominal.pitch_radius_mm + module_mm,
    outer_radius_mm: ring_nominal.pitch_radius_mm - 1.25 * module_mm,
  }
  let center_delta = if p.tolerance_mm > 0.0 {
    p.tolerance_mm * 2.0
  } else {
    0.0
  }
  let center_distance = sun.pitch_radius_mm +
    planet.pitch_radius_mm +
    center_delta
  let tan_beta_pitch = @math.tan(ha) *
    p.planet_teeth.to_double() /
    (p.planet_teeth + 2).to_double()
  let helix_angle_sun = hb_clamp(
    @math.atan(
      tan_beta_pitch * (p.sun_teeth + 2).to_double() / p.sun_teeth.to_double(),
    ) /
    hb_deg,
    0.0,
    45.0,
  )
  let planets : Array[HerringbonePlanetPlacement] = []
  for j in 0..<p.planet_count {
    let theta = hb_two_pi * j.to_double() / p.planet_count.to_double()
    let s = hb_frac(p.sun_teeth.to_double() * theta / hb_two_pi)
    let phi = theta +
      @math.PI -
      hb_two_pi / p.planet_teeth.to_double() * (0.5 - s)
    planets.push({
      x: center_distance * @math.cos(theta),
      z: center_distance * @math.sin(theta),
      phi_deg: hb_norm_angle(phi) / hb_deg,
    })
  }
  {
    module_mm,
    gear_length_mm: p.gear_length_mm,
    helix_angle_deg: ha / hb_deg,
    helix_angle_sun_deg: helix_angle_sun,
    pressure_angle_deg: p.pressure_angle_deg,
    num_elbows: p.num_elbows,
    resolution: p.resolution,
    hole_type: p.hole_type,
    hole_radius_mm: p.hole_radius_mm,
    tolerance_mm: p.tolerance_mm,
    outer_thickness_mm: p.outer_thickness_mm,
    sun,
    planet,
    ring,
    ring_teeth: p.ring_teeth,
    center_distance_mm: center_distance,
    center_delta_mm: center_delta,
    ring_outer_radius_mm: ring.pitch_radius_mm +
    module_mm +
    center_delta +
    p.tolerance_mm / @math.sin(pa) +
    p.outer_thickness_mm,
    sun_direction: 1.0,
    planet_direction: -1.0,
    planets,
  }
}

///|
fn hb_gear_dims(
  module_mm : Double,
  pressure_angle : Double,
  num_teeth : Int32,
) -> HerringboneGearDims {
  let pitch = module_mm * num_teeth.to_double() / 2.0
  {
    num_teeth,
    pitch_radius_mm: pitch,
    base_radius_mm: pitch * @math.cos(pressure_angle),
    root_radius_mm: pitch - 1.25 * module_mm,
    outer_radius_mm: pitch + module_mm,
  }
}

///|
fn hb_deg2rad(d : Double) -> Double {
  d * hb_deg
}

///|
fn hb_clamp(value : Double, lo : Double, hi : Double) -> Double {
  if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

///|
fn hb_frac(x : Double) -> Double {
  x - x.floor()
}

///|
fn hb_dmod(a : Double, b : Double) -> Double {
  a - b * (a / b).floor()
}

///|
fn hb_norm_angle(a : Double) -> Double {
  let mut angle = hb_dmod(a, hb_two_pi)
  if angle < 0.0 {
    angle = angle + hb_two_pi
  }
  angle
}

///|
fn hb_radius_of(pt : (Double, Double)) -> Double {
  Double::sqrt(pt.0 * pt.0 + pt.1 * pt.1)
}

///|
fn hb_sq_dist(a : (Double, Double), b : (Double, Double)) -> Double {
  let dx = a.0 - b.0
  let dz = a.1 - b.1
  dx * dx + dz * dz
}

///|
fn hb_rotate_xz(pt : (Double, Double), theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (c * pt.0 - s * pt.1, s * pt.0 + c * pt.1)
}

///|
fn hb_involute_xz(radius : Double, theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (radius * (c + theta * s), radius * (s - theta * c))
}

///|
fn hb_involute_theta(radius : Double, distance : Double) -> Double {
  let x = distance / radius
  Double::sqrt(x * x - 1.0)
}

///|
fn hb_clean_polygon(
  pts : Array[(Double, Double)],
  eps2 : Double,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for pt in pts {
    let keep = out.length() == 0 || hb_sq_dist(out[out.length() - 1], pt) > eps2
    if keep {
      out.push(pt)
    }
  }
  while out.length() > 1 && hb_sq_dist(out[0], out[out.length() - 1]) <= eps2 {
    let _ = out.pop()
  }
  out
}

///|
/// hb_gear_outline returns the complete external-gear boundary in the XZ plane,
/// clockwise, exactly as the original generator builds its tooth faces.
fn hb_gear_outline(
  module_mm : Double,
  pressure_angle_deg : Double,
  num_teeth : Int32,
  resolution : Int32,
) -> Array[(Double, Double)] {
  let pa = hb_deg2rad(pressure_angle_deg)
  let n = num_teeth.to_double()
  let pitch_radius = module_mm * n / 2.0
  let base_radius = pitch_radius * @math.cos(pa)
  let root_radius = pitch_radius - 1.25 * module_mm
  let outer_radius = pitch_radius + module_mm
  let backlash = 0.25 * @math.PI * @math.cos(pa) / (n * module_mm)
  let pitch_point = hb_involute_xz(
    base_radius,
    hb_involute_theta(base_radius, pitch_radius),
  )
  let face_angle = @math.atan2(pitch_point.1, pitch_point.0)
  let backlash_angle = backlash / (2.0 * pitch_radius)
  let center_angle = @math.PI / (2.0 * n) + face_angle - backlash_angle
  let start_angle = hb_involute_theta(
    base_radius,
    if root_radius > base_radius {
      root_radius
    } else {
      base_radius
    },
  )
  let stop_angle = hb_involute_theta(base_radius, outer_radius)
  let d_theta = (stop_angle - start_angle) / HB_INVOLUTE_POINTS.to_double()
  let inv : Array[(Double, Double)] = []
  if root_radius < base_radius {
    inv.push(hb_rotate_xz((root_radius, 0.0), -center_angle))
  }
  let mut angle = start_angle
  for _i in 0..<(HB_INVOLUTE_POINTS + 1) {
    inv.push(hb_rotate_xz(hb_involute_xz(base_radius, angle), -center_angle))
    angle = angle + d_theta
  }
  let num_facets = inv.length()
  let arc_tip = inv[num_facets - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<resolution {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / resolution.to_double()
    inv.push(hb_rotate_xz((outer_radius, 0.0), phi))
  }
  for i in 1..<=num_facets {
    let pt = inv[num_facets - i]
    inv.push((pt.0, -pt.1))
  }
  let first_angle = @math.atan2(inv[0].1, inv[0].0)
  let last_angle = @math.atan2(inv[inv.length() - 1].1, inv[inv.length() - 1].0)
  let involute_arc_angle = Double::abs(last_angle - first_angle)
  let gap_arc_angle = hb_two_pi / n - involute_arc_angle
  let gap_delta = gap_arc_angle / resolution.to_double()
  let outline : Array[(Double, Double)] = []
  let num_inv = inv.length()
  for i in 0..<num_teeth {
    let theta = -i.to_double() * hb_two_pi / n
    for k in 0..<num_inv {
      outline.push(hb_rotate_xz(inv[num_inv - 1 - k], theta))
    }
    let lower_root = hb_rotate_xz(inv[0], theta)
    for j in 1..<resolution {
      outline.push(hb_rotate_xz(lower_root, -j.to_double() * gap_delta))
    }
  }
  hb_clean_polygon(outline, 1.0e-4)
}

///|
/// hb_external_boundary returns the clockwise outer boundary used for the ring
/// envelope, without the tip arc.
fn hb_external_boundary(
  module_mm : Double,
  pressure_angle_deg : Double,
  num_teeth : Int32,
  root_radius : Double,
  outer_radius : Double,
  resolution : Int32,
) -> Array[(Double, Double)] {
  let pa = hb_deg2rad(pressure_angle_deg)
  let n = num_teeth.to_double()
  let pitch_radius = module_mm * n / 2.0
  let base_radius = pitch_radius * @math.cos(pa)
  let face_angle = @math.tan(pa) - pa
  let backlash = 0.25 * @math.PI * @math.cos(pa) / (n * module_mm)
  let backlash_angle = backlash / (2.0 * pitch_radius)
  let center_angle = @math.PI / (2.0 * n) + face_angle - backlash_angle
  let start_angle = hb_involute_theta(
    base_radius,
    if root_radius > base_radius {
      root_radius
    } else {
      base_radius
    },
  )
  let stop_angle = hb_involute_theta(base_radius, outer_radius)
  let d_theta = (stop_angle - start_angle) / HB_INVOLUTE_POINTS.to_double()
  let inv : Array[(Double, Double)] = []
  if root_radius < base_radius {
    inv.push(hb_rotate_xz((root_radius, 0.0), -center_angle))
  }
  let mut angle = start_angle
  for _i in 0..<(HB_INVOLUTE_POINTS + 1) {
    inv.push(hb_rotate_xz(hb_involute_xz(base_radius, angle), -center_angle))
    angle = angle + d_theta
  }
  let num_facets = inv.length()
  let arc_tip = inv[num_facets - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<resolution {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / resolution.to_double()
    inv.push(hb_rotate_xz((outer_radius, 0.0), phi))
  }
  for i in 1..<=num_facets {
    let pt = inv[num_facets - i]
    inv.push((pt.0, -pt.1))
  }
  let first_angle = @math.atan2(inv[0].1, inv[0].0)
  let last_angle = @math.atan2(inv[inv.length() - 1].1, inv[inv.length() - 1].0)
  let involute_arc_angle = Double::abs(last_angle - first_angle)
  let gap_arc_angle = hb_two_pi / n - involute_arc_angle
  let gap_delta = gap_arc_angle / resolution.to_double()
  let profile : Array[(Double, Double)] = []
  let num_inv = inv.length()
  for tooth in 0..<num_teeth {
    let tooth_angle = -hb_two_pi * tooth.to_double() / n
    for k in 1..<=num_inv {
      profile.push(hb_rotate_xz(inv[num_inv - k], tooth_angle))
    }
    let lower_root = hb_rotate_xz(inv[0], tooth_angle)
    for j in 1..<resolution {
      profile.push(hb_rotate_xz(lower_root, -j.to_double() * gap_delta))
    }
  }
  profile
}

///|
priv struct HBRingGeometry {
  inner : Array[(Double, Double)]
  outer_radius : Double
  phase : Double
  ring_scale : Double
  max_helix_mate : Double
}

///|
fn hb_ring_geometry(layout : HerringbonePlanetaryLayout) -> HBRingGeometry {
  let module_mm = layout.module_mm
  let n = layout.ring_teeth.to_double()
  let ring_pitch = module_mm * n / 2.0
  let mate_pitch = module_mm * layout.planet.num_teeth.to_double() / 2.0
  let mate_outer = mate_pitch + module_mm
  let nominal_center = ring_pitch - mate_pitch
  let center = if layout.center_distance_mm <= 0.0 {
    nominal_center
  } else {
    layout.center_distance_mm
  }
  let center_delta = if center > nominal_center {
    center - nominal_center
  } else {
    0.0
  }
  let phantom_root = ring_pitch - module_mm
  let phantom_tip = ring_pitch + module_mm
  let profile = hb_external_boundary(
    module_mm,
    layout.pressure_angle_deg,
    layout.ring_teeth,
    phantom_root,
    phantom_tip,
    layout.resolution,
  )
  let profile = hb_clean_polygon(profile, 1.0e-4)
  let mut max_r = 0.0
  for pt in profile {
    let r = hb_radius_of(pt)
    if r > max_r {
      max_r = r
    }
  }
  let radial_offset = center_delta +
    layout.tolerance_mm / @math.sin(hb_deg2rad(layout.pressure_angle_deg))
  let offset_profile = profile.map(fn(pt) {
    let r = hb_radius_of(pt)
    if r > 0.0 {
      let s = (r + radial_offset) / r
      (pt.0 * s, pt.1 * s)
    } else {
      pt
    }
  })
  let inner = hb_clean_polygon(offset_profile, 1.0e-4)
  let outer_radius = max_r + radial_offset + layout.outer_thickness_mm
  let mate_pitch_angle = hb_two_pi / layout.planet.num_teeth.to_double()
  let ring_pitch_angle = hb_two_pi / n
  let mate_rotation = hb_deg2rad(layout.planets[0].phi_deg)
  let mut phase = ring_pitch_angle *
    hb_dmod(mate_rotation / mate_pitch_angle, 1.0)
  if phase < 0.0 {
    phase = phase + ring_pitch_angle
  }
  let max_helix_mate = @math.tan(hb_deg2rad(layout.helix_angle_deg)) *
    (layout.gear_length_mm / 2.0) /
    mate_outer
  {
    inner,
    outer_radius,
    phase,
    ring_scale: mate_pitch / ring_pitch,
    max_helix_mate,
  }
}

///|
fn hb_gear_holes(
  layout : HerringbonePlanetaryLayout,
  g : HerringboneGearDims,
) -> Array[Array[(Double, Double)]] {
  let hole_type = layout.hole_type
  if hole_type == "None" {
    []
  } else if hole_type == "Circular" {
    [
      hb_circle_outline(
        layout.hole_radius_mm,
        g.num_teeth * layout.resolution,
        false,
      ),
    ]
  } else if hole_type == "Squared" {
    [hb_polygon_hole(4, layout.hole_radius_mm)]
  } else if hole_type == "Hexagonal" {
    [hb_polygon_hole(6, layout.hole_radius_mm)]
  } else if hole_type == "Octagonal" {
    [hb_polygon_hole(8, layout.hole_radius_mm)]
  } else {
    []
  }
}

///|
fn hb_polygon_hole(sides : Int32, inradius : Double) -> Array[(Double, Double)] {
  let circumradius = inradius / @math.cos(@math.PI / sides.to_double())
  let pts : Array[(Double, Double)] = []
  for i in 0..<sides {
    let a = hb_two_pi * i.to_double() / sides.to_double()
    pts.push((circumradius * @math.cos(a), circumradius * @math.sin(a)))
  }
  pts
}

///|
fn hb_circle_outline(
  radius : Double,
  segments : Int32,
  clockwise : Bool,
) -> Array[(Double, Double)] {
  let n = if segments < 3 { 3 } else { segments }
  let pts : Array[(Double, Double)] = []
  for i in 0..<n {
    let a = hb_two_pi * i.to_double() / n.to_double()
    let angle = if clockwise { -a } else { a }
    pts.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  pts
}

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------

///|
/// hb_swept_gear_shape builds the herringbone gear by sweeping the outline
/// through `num_elbows + 1` linearly twisted extrusions, exactly like the
/// original generator (so dimensions and volumes are preserved).
fn hb_swept_gear_shape(
  outline : Array[(Double, Double)],
  holes : Array[Array[(Double, Double)]],
  gear_length : Double,
  num_elbows : Int32,
  max_rotation : Double,
  direction : Double,
  straight_holes~ : Bool = false,
  straight_outline~ : Bool = true,
) -> @cad.Shape {
  let path = hb_sweep_path(gear_length, num_elbows, max_rotation, direction)
  let profile = @cad.SweepProfile::new(
    hb_profile_points(outline),
    holes=holes.map(fn(hole) { hb_profile_points(hole) }),
    normal_dir=(0.0, 0.0, 1.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  @cad.SweptProfile::new(path~, profile~, straight_holes~, straight_outline~)
}

///|
fn hb_sweep_path(
  gear_length : Double,
  num_elbows : Int32,
  max_rotation : Double,
  direction : Double,
) -> @cad.SweepPath {
  let chunks = num_elbows + 1
  let max_step = HB_MAX_SWEEP_STEP_DEG * hb_deg
  let steps = if max_rotation <= max_step {
    1
  } else {
    let n = @math.ceil(max_rotation / max_step).to_int()
    if n < 1 {
      1
    } else {
      n
    }
  }
  let total = chunks * steps
  let points : Array[@cad.Vec3] = []
  let normals : Array[@cad.Vec3] = []
  let tangents : Array[@cad.Vec3] = []
  for i in 0..<(total + 1) {
    let y = gear_length * i.to_double() / total.to_double()
    let chunk = if i == total { chunks - 1 } else { i / steps }
    let within = if i == total {
      1.0
    } else {
      (i % steps).to_double() / steps.to_double()
    }
    let start_rotation = if chunk % 2 == 0 { 0.0 } else { max_rotation }
    let end_rotation = if chunk % 2 == 0 { max_rotation } else { 0.0 }
    let helix_rotation = start_rotation +
      (end_rotation - start_rotation) * within
    let angle = -direction * helix_rotation
    points.push((0.0, y, 0.0))
    normals.push((@math.cos(angle), 0.0, @math.sin(angle)))
    tangents.push((0.0, 1.0, 0.0))
  }
  { points, normals, tangents, }
}

///|
fn hb_profile_points(pts : Array[(Double, Double)]) -> Array[@cad.Vec3] {
  pts.map(fn(pt) { (-pt.1, pt.0, 0.0) })
}

///|
fn hb_arc_segments(pts : Array[(Double, Double)]) -> Array[@cad.ProfileSegment] {
  @gears.arc_outline_runs(pts.map(fn(pt) { (pt.0, -pt.1) }))
}

///|
/// hb_arc_gear_shape builds a straight gear as an exact line/arc extrusion of
/// the top-face outline. The shape is flat (XY plane, +Z axis); the caller's
/// placement rotates it into the native +Y frame.
fn hb_arc_gear_shape(
  outline : Array[(Double, Double)],
  holes : Array[Array[(Double, Double)]],
  gear_length : Double,
) -> @cad.Shape {
  let hole_segments = holes.map(fn(hole) { hb_arc_segments(hole) })
  @cad.ExtrudedArcProfile::new(
    hb_arc_segments(outline),
    gear_length,
    holes=hole_segments,
  ).as_shape()
}

///|
fn hb_arc_ring_shape(
  outer_radius : Double,
  inner : Array[(Double, Double)],
  gear_length : Double,
) -> @cad.Shape {
  @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * outer_radius),
    gear_length,
    holes=[hb_arc_segments(inner)],
  ).as_shape()
}
