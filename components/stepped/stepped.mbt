///|
/// Parametric stepped (compound) planetary gearbox (`gmlewis/step/components/stepped`).
///
/// Each orbiting planet is a rigid two-tier gear:
/// - **Tier 1 (`planet_sun_teeth`, larger)** meshes with the central **sun**
///   (`sun_teeth`) at `z = 0 .. tier1_length_mm`.
/// - **Tier 2 (`planet_ring_teeth`, smaller)** meshes with the fixed outer
///   **ring** (`ring_teeth = sun_teeth + planet_sun_teeth + planet_ring_teeth`)
///   at `z = tier1_length_mm + tier_gap_mm .. total_length_mm`.
///
/// Exact reduction ratio (fixed ring, carrier output):
///   `R = 1 + (ring_teeth * planet_sun_teeth) / (sun_teeth * planet_ring_teeth)`
///
/// Bridges the gap between standard planetary (3–7:1) and cycloidal/harmonic
/// (15–50:1), achieving 10:1–25:1 in a single highly efficient, backdrivable,
/// 100% rigid coaxial stage.

///|
const STEPPED_PI : Double = 3.141592653589793

///|
const STEPPED_TWO_PI : Double = 6.283185307179586

///|
/// Input parameters for a stepped (compound) planetary stage.
pub(all) struct SteppedPlanetaryParams {
  /// Gear module in mm (shared between both tiers for exact coaxial mesh).
  module_mm : Double
  /// Input sun tooth count `Z_s`.
  sun_teeth : Int32
  /// Large planet tier tooth count `Z_p1` (meshes with sun).
  planet_sun_teeth : Int32
  /// Small planet tier tooth count `Z_p2` (meshes with fixed outer ring).
  planet_ring_teeth : Int32
  /// Number of equally spaced stepped planets (`>= 2`).
  planet_count : Int32
  /// Axial face width of tier 1 (sun + large planet), in mm.
  tier1_length_mm : Double
  /// Axial face width of tier 2 (small planet + ring), in mm.
  tier2_length_mm : Double
  /// Axial clearance gap between tier 1 and tier 2, in mm.
  tier_gap_mm : Double
  /// Involute pressure angle in degrees (default `20.0`).
  pressure_angle_deg : Double
  /// Input shaft bore radius in the sun gear, in mm.
  sun_bore_radius_mm : Double
  /// Planet pin/bearing bore radius through each stepped planet, in mm.
  planet_bore_radius_mm : Double
  /// Radial wall thickness outside the tier-1 envelope / ring root, in mm.
  outer_wall_mm : Double
  /// Radial flank backlash / printing clearance, in mm.
  tolerance_mm : Double
}

///|
/// Builds and validates `SteppedPlanetaryParams`.
pub fn SteppedPlanetaryParams::new(
  module_mm~ : Double = 1.5,
  sun_teeth~ : Int32 = 12,
  planet_sun_teeth~ : Int32 = 24,
  planet_ring_teeth~ : Int32 = 10,
  planet_count~ : Int32 = 3,
  tier1_length_mm~ : Double = 8.0,
  tier2_length_mm~ : Double = 8.0,
  tier_gap_mm~ : Double = 1.0,
  pressure_angle_deg~ : Double = 20.0,
  sun_bore_radius_mm~ : Double = 4.1,
  planet_bore_radius_mm~ : Double = 3.5,
  outer_wall_mm~ : Double = 6.0,
  tolerance_mm~ : Double = @common.DEFAULT_GEAR_TOLERANCE_MM,
) -> Result[SteppedPlanetaryParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if sun_teeth < 8 {
    return Err(@common.InvalidParameter("sun_teeth must be >= 8"))
  }
  if planet_sun_teeth < 10 || planet_ring_teeth < 8 {
    return Err(
      @common.InvalidParameter(
        "planet_sun_teeth must be >= 10 and planet_ring_teeth must be >= 8",
      ),
    )
  }
  if planet_count < 2 {
    return Err(@common.InvalidParameter("planet_count must be >= 2"))
  }
  if tier1_length_mm <= 0.0 || tier2_length_mm <= 0.0 || tier_gap_mm < 0.0 {
    return Err(
      @common.InvalidParameter("tier lengths must be positive and gap >= 0"),
    )
  }
  if outer_wall_mm <= 0.0 || tolerance_mm < 0.0 {
    return Err(
      @common.InvalidParameter("outer_wall_mm must be > 0 and tolerance >= 0"),
    )
  }
  let sun_root = module_mm * (sun_teeth.to_double() / 2.0 - 1.25)
  if sun_bore_radius_mm <= 0.0 || sun_bore_radius_mm >= sun_root - 1.0 {
    return Err(
      @common.InvalidParameter(
        "sun_bore_radius_mm does not fit inside sun root",
      ),
    )
  }
  let min_planet_teeth = if planet_sun_teeth < planet_ring_teeth {
    planet_sun_teeth
  } else {
    planet_ring_teeth
  }
  let planet_min_root = module_mm * (min_planet_teeth.to_double() / 2.0 - 1.25)
  if planet_bore_radius_mm <= 0.0 ||
    planet_bore_radius_mm >= planet_min_root - 1.0 {
    return Err(
      @common.InvalidParameter(
        "planet_bore_radius_mm does not fit inside smaller planet tier root",
      ),
    )
  }
  // Adjacent large planets must not collide on the carrier circle.
  let center_dist = module_mm * (sun_teeth + planet_sun_teeth).to_double() / 2.0
  let p1_outer = module_mm * (planet_sun_teeth.to_double() / 2.0 + 1.0)
  let chord = 2.0 *
    center_dist *
    @math.sin(STEPPED_PI / planet_count.to_double())
  if 2.0 * p1_outer >= chord - 0.5 {
    return Err(
      @common.InvalidParameter(
        "adjacent tier-1 planets collide (2 * outer = \{2.0 * p1_outer} mm, chord = \{chord} mm); reduce planet_count or planet_sun_teeth",
      ),
    )
  }
  // Equal-spacing assembly condition for compound planetary:
  // (Z_s * Z_p2 + Z_r * Z_p1) must be divisible by planet_count.
  let ring_teeth = sun_teeth + planet_sun_teeth + planet_ring_teeth
  if (sun_teeth * planet_ring_teeth + ring_teeth * planet_sun_teeth) %
    planet_count !=
    0 {
    return Err(
      @common.InvalidParameter(
        "tooth counts (\{sun_teeth}/\{planet_sun_teeth}/\{planet_ring_teeth}/\{ring_teeth}) do not satisfy equal-spacing assembly condition for \{planet_count} planets",
      ),
    )
  }
  Ok({
    module_mm,
    sun_teeth,
    planet_sun_teeth,
    planet_ring_teeth,
    planet_count,
    tier1_length_mm,
    tier2_length_mm,
    tier_gap_mm,
    pressure_angle_deg,
    sun_bore_radius_mm,
    planet_bore_radius_mm,
    outer_wall_mm,
    tolerance_mm,
  })
}

///|
/// Derived geometry and kinematics for a stepped planetary stage.
pub(all) struct SteppedPlanetaryLayout {
  params : SteppedPlanetaryParams
  /// Fixed outer ring tooth count (`Z_s + Z_p1 + Z_p2`).
  ring_teeth : Int32
  /// Exact signed reduction ratio (`1 + (Z_r * Z_p1) / (Z_s * Z_p2)`).
  signed_reduction : Double
  /// Carrier orbit radius `a = m * (Z_s + Z_p1) / 2`.
  center_distance_mm : Double
  /// Tier-1 planet outer radius.
  planet_sun_outer_radius_mm : Double
  /// Tier-2 planet outer radius.
  planet_ring_outer_radius_mm : Double
  /// Ring inner root radius (at tier 2).
  ring_root_radius_mm : Double
  /// Maximum radial envelope needed inside the outer casing (max of tier-1
  /// swept planet radius and tier-2 ring root radius).
  casing_inner_envelope_mm : Double
  /// Outer radius of the integrated casing ring (`casing_inner_envelope + outer_wall`).
  ring_outer_radius_mm : Double
  /// Total axial length (`tier1 + gap + tier2`).
  total_length_mm : Double
  /// Planet orbit centers `(x, y)` in mm.
  planets : Array[(Double, Double)]
}

///|
/// Computes the derived layout of a stepped planetary stage.
pub fn stepped_planetary_layout(
  params : SteppedPlanetaryParams,
) -> SteppedPlanetaryLayout {
  let m = params.module_mm
  let ring_teeth = params.sun_teeth +
    params.planet_sun_teeth +
    params.planet_ring_teeth
  let signed_reduction = 1.0 +
    ring_teeth.to_double() *
    params.planet_sun_teeth.to_double() /
    (params.sun_teeth.to_double() * params.planet_ring_teeth.to_double())
  let center_distance_mm = m *
    (params.sun_teeth + params.planet_sun_teeth).to_double() /
    2.0
  let planet_sun_outer_radius_mm = m *
    (params.planet_sun_teeth.to_double() / 2.0 + 1.0)
  let planet_ring_outer_radius_mm = m *
    (params.planet_ring_teeth.to_double() / 2.0 + 1.0)
  let ring_root_radius_mm = m * (ring_teeth.to_double() / 2.0 + 1.25)
  let tier1_sweep = center_distance_mm + planet_sun_outer_radius_mm + 1.0
  let casing_inner_envelope_mm = if tier1_sweep > ring_root_radius_mm {
    tier1_sweep
  } else {
    ring_root_radius_mm
  }
  let ring_outer_radius_mm = casing_inner_envelope_mm + params.outer_wall_mm
  let total_length_mm = params.tier1_length_mm +
    params.tier_gap_mm +
    params.tier2_length_mm
  let planets : Array[(Double, Double)] = []
  for i in 0..<params.planet_count {
    let a = STEPPED_TWO_PI * i.to_double() / params.planet_count.to_double()
    planets.push(
      (center_distance_mm * @math.cos(a), center_distance_mm * @math.sin(a)),
    )
  }
  {
    params,
    ring_teeth,
    signed_reduction,
    center_distance_mm,
    planet_sun_outer_radius_mm,
    planet_ring_outer_radius_mm,
    ring_root_radius_mm,
    casing_inner_envelope_mm,
    ring_outer_radius_mm,
    total_length_mm,
    planets,
  }
}

///|
/// Builds a complete parametric stepped (compound) planetary gearbox stage as a
/// `@common.Component` along `+Z` (or `+Y` when `y_up=true`).
pub fn stepped_planetary_gearbox(
  params : SteppedPlanetaryParams,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = stepped_planetary_layout(params)
  let name = "stepped-planetary-m\{@cad.fmt_double(params.module_mm, None)}-z\{params.sun_teeth}-\{params.planet_sun_teeth}-\{params.planet_ring_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "sun-gear", "stepped-two-tier-planets", "fixed-tier2-ring-gear", "exact-involute-extrusions",
    ],
    approximated=[
      @common.Approximation::new(
        feature="involute-flanks",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="smooth involute arc runs",
      ),
    ],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Stepped planetary \{@cad.fmt_double(layout.signed_reduction, None)}:1 (m=\{@cad.fmt_double(params.module_mm, None)}, Zs=\{params.sun_teeth}, Zp1=\{params.planet_sun_teeth}, Zp2=\{params.planet_ring_teeth}, Zr=\{layout.ring_teeth})",
      family="stepped planetary gearbox",
      size="m\{@cad.fmt_double(params.module_mm, None)}-\{params.sun_teeth}t-\{params.planet_count}p",
      length_mm=layout.total_length_mm,
      source="Parametric compound stepped planetary gearbox.",
    ),
    description="Backdrivable high-ratio stepped (compound) planetary stage: sun meshes with large planet tier, small planet tier meshes with fixed outer ring.",
    features~,
  )
  // 1. Sun gear (z = 0 .. tier1_length).
  let sun_outline = @gears.external_involute_outline(
    params.module_mm,
    params.sun_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let sun_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(sun_outline),
    params.tier1_length_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.sun_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    sun_shape,
    name="sun",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::identity(),
  )
  // 2. Stepped planets (tier 1 + spacer + tier 2).
  let p1_outline = @gears.external_involute_outline(
    params.module_mm,
    params.planet_sun_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let p2_outline = @gears.external_involute_outline(
    params.module_mm,
    params.planet_ring_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let p_hole = [@gears.arc_circle_segments(2.0 * params.planet_bore_radius_mm)]
  let p1_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(p1_outline),
    params.tier1_length_mm,
    holes=p_hole,
  ).as_shape()
  let p2_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(p2_outline),
    params.tier2_length_mm,
    holes=p_hole,
  ).as_shape()
  let tier2_z = params.tier1_length_mm + params.tier_gap_mm
  for i in 0..<layout.planets.length() {
    let (px, py) = layout.planets[i]
    comp = comp.add_layer(
      p1_shape,
      name="planet-\{i + 1}-tier1",
      color=@cad.Rgb::blue(),
      placement=@common.Placement::translation(px, py, 0.0),
    )
    comp = comp.add_layer(
      p2_shape,
      name="planet-\{i + 1}-tier2",
      color=@cad.Rgb::new(0.25, 0.55, 0.95),
      placement=@common.Placement::translation(px, py, tier2_z),
    )
  }
  // 3. Fixed tier-2 internal ring gear (z = tier2_z .. total_length).
  let ring_inner = match
    @gears.internal_involute_ring_profile(
      params.module_mm,
      layout.ring_teeth,
      params.pressure_angle_deg,
      backlash_mm=params.tolerance_mm,
    ) {
    Ok(pts) => pts
    Err(e) => return Err(e)
  }
  let ring_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * layout.ring_outer_radius_mm),
    params.tier2_length_mm,
    holes=[@gears.arc_outline_runs(ring_inner)],
  ).as_shape()
  comp = comp.add_layer(
    ring_shape,
    name="ring",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::translation(0.0, 0.0, tier2_z),
  )
  // Tier-1 smooth housing sleeve (z = 0 .. tier2_z) so the full stage casing
  // is continuous from z = 0 to total_length_mm.
  let sleeve_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * layout.ring_outer_radius_mm),
    tier2_z,
    holes=[@gears.arc_circle_segments(2.0 * layout.casing_inner_envelope_mm)],
  ).as_shape()
  comp = comp.add_layer(
    sleeve_shape,
    name="ring-sleeve",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::identity(),
  )
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-outer-seat",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=2.0 * layout.ring_outer_radius_mm,
        depth_mm=layout.total_length_mm,
        description="outer ring cylindrical seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "input-bore",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.sun_bore_radius_mm,
        depth_mm=params.tier1_length_mm,
        description="sun input shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          layout.total_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * layout.center_distance_mm,
        description="carrier output plane",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
