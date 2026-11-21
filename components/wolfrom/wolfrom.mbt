///|
/// Parametric Wolfrom (3K) planetary gearbox (`gmlewis/step/components/wolfrom`).
///
/// A single sun gear drives full-width rigid planets that simultaneously mesh
/// with two coaxial internal ring gears differing by `ring_tooth_diff` teeth:
/// - **Fixed ring (`ring-fixed`)**: `Z_r1 = Z_s + 2 * Z_p` (bolted to casing).
/// - **Output ring (`ring-output`)**: `Z_r2 = Z_r1 + ring_tooth_diff` (free to
///   rotate as the high-ratio output).
///
/// Exact Willis reduction ratio (sun input, ring-fixed held, ring-output driven):
///   `R = ((Z_s + Z_r1) * Z_r2) / (Z_s * (Z_r2 - Z_r1))`
///
/// Example default (`Z_s=12, Z_p=18, Z_r1=48, Z_r2=51`, 3 planets): **85:1**
/// in one compact, 100% rigid, 3D-printable coaxial stage with no flexspline.

///|
const WOLF_PI : Double = 3.141592653589793

///|
const WOLF_TWO_PI : Double = 6.283185307179586

///|
/// Input parameters for a Wolfrom (3K) planetary stage.
pub(all) struct WolfromParams {
  /// Base gear module `m1` (used by sun, planets, and fixed ring), in mm.
  module_mm : Double
  /// Sun tooth count `Z_s`.
  sun_teeth : Int32
  /// Planet tooth count `Z_p`.
  planet_teeth : Int32
  /// Tooth difference `Z_r2 - Z_r1` (non-zero, must be divisible by `planet_count`).
  ring_tooth_diff : Int32
  /// Number of equally spaced planets (`>= 2`).
  planet_count : Int32
  /// Axial face width of the fixed ring zone, in mm.
  fixed_ring_length_mm : Double
  /// Axial face width of the rotating output ring zone, in mm.
  output_ring_length_mm : Double
  /// Axial clearance gap between the fixed ring and output ring, in mm.
  ring_gap_mm : Double
  /// Involute pressure angle in degrees (default `20.0`).
  pressure_angle_deg : Double
  /// Sun input shaft bore radius, in mm.
  sun_bore_radius_mm : Double
  /// Planet bore radius, in mm.
  planet_bore_radius_mm : Double
  /// Radial wall thickness outside the larger ring root, in mm.
  outer_wall_mm : Double
  /// Radial backlash / print clearance, in mm.
  tolerance_mm : Double
}

///|
/// Builds and validates `WolfromParams`.
pub fn WolfromParams::new(
  module_mm~ : Double = 1.5,
  sun_teeth~ : Int32 = 12,
  planet_teeth~ : Int32 = 18,
  ring_tooth_diff~ : Int32 = 3,
  planet_count~ : Int32 = 3,
  fixed_ring_length_mm~ : Double = 8.0,
  output_ring_length_mm~ : Double = 8.0,
  ring_gap_mm~ : Double = 1.0,
  pressure_angle_deg~ : Double = 20.0,
  sun_bore_radius_mm~ : Double = 4.1,
  planet_bore_radius_mm~ : Double = 4.0,
  outer_wall_mm~ : Double = 6.0,
  tolerance_mm~ : Double = 0.15,
) -> Result[WolfromParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if sun_teeth < 8 || planet_teeth < 8 {
    return Err(
      @common.InvalidParameter("sun_teeth and planet_teeth must be >= 8"),
    )
  }
  if planet_count < 2 {
    return Err(@common.InvalidParameter("planet_count must be >= 2"))
  }
  if ring_tooth_diff == 0 || ring_tooth_diff % planet_count != 0 {
    return Err(
      @common.InvalidParameter(
        "ring_tooth_diff must be non-zero and divisible by planet_count",
      ),
    )
  }
  if fixed_ring_length_mm <= 0.0 ||
    output_ring_length_mm <= 0.0 ||
    ring_gap_mm < 0.0 {
    return Err(
      @common.InvalidParameter("ring lengths must be positive and gap >= 0"),
    )
  }
  if outer_wall_mm <= 0.0 || tolerance_mm < 0.0 {
    return Err(
      @common.InvalidParameter("outer_wall_mm must be > 0 and tolerance >= 0"),
    )
  }
  let r1_teeth = sun_teeth + 2 * planet_teeth
  let r2_teeth = r1_teeth + ring_tooth_diff
  if r2_teeth <= planet_teeth + 4 {
    return Err(
      @common.InvalidParameter("output ring tooth count Z_r2 is too small"),
    )
  }
  if (sun_teeth + r1_teeth) % planet_count != 0 {
    return Err(
      @common.InvalidParameter(
        "(sun_teeth + fixed_ring_teeth) must be divisible by planet_count",
      ),
    )
  }
  let center_dist = module_mm * (sun_teeth + planet_teeth).to_double() / 2.0
  let p_outer = module_mm * (planet_teeth.to_double() / 2.0 + 1.0)
  let chord = 2.0 * center_dist * @math.sin(WOLF_PI / planet_count.to_double())
  if 2.0 * p_outer >= chord - 0.5 {
    return Err(
      @common.InvalidParameter(
        "adjacent planets collide; reduce planet_count or planet_teeth",
      ),
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
  let planet_root = module_mm * (planet_teeth.to_double() / 2.0 - 1.25)
  if planet_bore_radius_mm <= 0.0 || planet_bore_radius_mm >= planet_root - 1.0 {
    return Err(
      @common.InvalidParameter(
        "planet_bore_radius_mm does not fit inside planet root",
      ),
    )
  }
  Ok({
    module_mm,
    sun_teeth,
    planet_teeth,
    ring_tooth_diff,
    planet_count,
    fixed_ring_length_mm,
    output_ring_length_mm,
    ring_gap_mm,
    pressure_angle_deg,
    sun_bore_radius_mm,
    planet_bore_radius_mm,
    outer_wall_mm,
    tolerance_mm,
  })
}

///|
/// Derived geometry and kinematics for a Wolfrom (3K) stage.
pub(all) struct WolfromLayout {
  params : WolfromParams
  /// Fixed ring tooth count `Z_r1 = Z_s + 2 * Z_p`.
  fixed_ring_teeth : Int32
  /// Output ring tooth count `Z_r2 = Z_r1 + ring_tooth_diff`.
  output_ring_teeth : Int32
  /// Effective module `m2` for the profile-shifted output ring so it shares
  /// the exact same center distance as the fixed ring.
  output_ring_module_mm : Double
  /// Signed Willis reduction ratio `((Z_s + Z_r1) * Z_r2) / (Z_s * (Z_r2 - Z_r1))`.
  signed_reduction : Double
  /// Reduction ratio magnitude.
  reduction_ratio : Double
  /// Planet orbit center distance `a = m * (Z_s + Z_p) / 2`.
  center_distance_mm : Double
  /// Fixed ring root radius.
  fixed_ring_root_radius_mm : Double
  /// Output ring root radius.
  output_ring_root_radius_mm : Double
  /// Outer radius of the fixed ring casing.
  ring_outer_radius_mm : Double
  /// Outer radius of the rotating output ring (fits inside casing smooth bore).
  output_ring_outer_radius_mm : Double
  /// Total axial length (`fixed_ring_length + ring_gap + output_ring_length`).
  total_length_mm : Double
  /// Planet orbit centers `(x, y)` in mm.
  planets : Array[(Double, Double)]
}

///|
/// Computes the derived layout of a Wolfrom (3K) stage.
pub fn wolfrom_layout(params : WolfromParams) -> WolfromLayout {
  let m1 = params.module_mm
  let fixed_ring_teeth = params.sun_teeth + 2 * params.planet_teeth
  let output_ring_teeth = fixed_ring_teeth + params.ring_tooth_diff
  let output_ring_module_mm = m1 *
    (fixed_ring_teeth - params.planet_teeth).to_double() /
    (output_ring_teeth - params.planet_teeth).to_double()
  let zs = params.sun_teeth.to_double()
  let zr1 = fixed_ring_teeth.to_double()
  let zr2 = output_ring_teeth.to_double()
  let signed_reduction = (zs + zr1) * zr2 / (zs * (zr2 - zr1))
  let reduction_ratio = signed_reduction.abs()
  let center_distance_mm = m1 *
    (params.sun_teeth + params.planet_teeth).to_double() /
    2.0
  let fixed_ring_root_radius_mm = m1 * (zr1 / 2.0 + 1.25)
  let output_ring_root_radius_mm = output_ring_module_mm * (zr2 / 2.0 + 1.25)
  let output_ring_outer_radius_mm = output_ring_root_radius_mm + 4.0
  let base_r = if fixed_ring_root_radius_mm > output_ring_outer_radius_mm + 1.0 {
    fixed_ring_root_radius_mm
  } else {
    output_ring_outer_radius_mm + 1.0
  }
  let ring_outer_radius_mm = base_r + params.outer_wall_mm
  let total_length_mm = params.fixed_ring_length_mm +
    params.ring_gap_mm +
    params.output_ring_length_mm
  let planets : Array[(Double, Double)] = []
  for i in 0..<params.planet_count {
    let a = WOLF_TWO_PI * i.to_double() / params.planet_count.to_double()
    planets.push(
      (center_distance_mm * @math.cos(a), center_distance_mm * @math.sin(a)),
    )
  }
  {
    params,
    fixed_ring_teeth,
    output_ring_teeth,
    output_ring_module_mm,
    signed_reduction,
    reduction_ratio,
    center_distance_mm,
    fixed_ring_root_radius_mm,
    output_ring_root_radius_mm,
    ring_outer_radius_mm,
    output_ring_outer_radius_mm,
    total_length_mm,
    planets,
  }
}

///|
/// Builds a complete parametric Wolfrom (3K) planetary gearbox stage as a
/// `@common.Component` along `+Z` (or `+Y` when `y_up=true`).
pub fn wolfrom_gearbox(
  params : WolfromParams,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = wolfrom_layout(params)
  let name = "wolfrom-m\{@cad.fmt_double(params.module_mm, None)}-z\{params.sun_teeth}-\{layout.fixed_ring_teeth}-\{layout.output_ring_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "sun-gear", "full-width-rigid-planets", "fixed-internal-ring", "rotating-output-ring",
    ],
    approximated=[
      @common.Approximation::new(
        feature="profile-shifted-output-ring",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="effective module matched to identical center distance",
      ),
    ],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Wolfrom 3K planetary \{@cad.fmt_double(layout.reduction_ratio, None)}:1 (Zs=\{params.sun_teeth}, Zp=\{params.planet_teeth}, Zr1=\{layout.fixed_ring_teeth}, Zr2=\{layout.output_ring_teeth})",
      family="wolfrom 3k planetary gearbox",
      size="m\{@cad.fmt_double(params.module_mm, None)}-\{params.sun_teeth}t-\{params.planet_count}p",
      length_mm=layout.total_length_mm,
      source="Parametric Wolfrom (3K) ultra-high-ratio rigid planetary gearbox.",
    ),
    description="High-ratio 100% rigid Wolfrom (3K) planetary stage: sun drives full-width planets spanning a fixed ring and a tooth-differing rotating output ring.",
    features~,
  )
  // 1. Sun gear (spans the fixed-ring engagement zone z = 0..fixed_ring_length).
  let sun_outline = @gears.external_involute_outline(
    params.module_mm,
    params.sun_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let sun_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(sun_outline),
    params.fixed_ring_length_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.sun_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    sun_shape,
    name="sun",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::identity(),
  )
  // 2. Full-width rigid planets spanning both rings (z = 0..total_length).
  let p_outline = @gears.external_involute_outline(
    params.module_mm,
    params.planet_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let p_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(p_outline),
    layout.total_length_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.planet_bore_radius_mm)],
  ).as_shape()
  for i in 0..<layout.planets.length() {
    let (px, py) = layout.planets[i]
    comp = comp.add_layer(
      p_shape,
      name="planet-\{i + 1}",
      color=@cad.Rgb::blue(),
      placement=@common.Placement::translation(px, py, 0.0),
    )
  }
  // 3. Fixed ring gear (z = 0..fixed_ring_length).
  let r1_inner = match
    @gears.internal_involute_ring_profile(
      params.module_mm,
      layout.fixed_ring_teeth,
      params.pressure_angle_deg,
      backlash_mm=params.tolerance_mm,
    ) {
    Ok(pts) => pts
    Err(e) => return Err(e)
  }
  let r1_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * layout.ring_outer_radius_mm),
    params.fixed_ring_length_mm,
    holes=[@gears.arc_outline_runs(r1_inner)],
  ).as_shape()
  comp = comp.add_layer(
    r1_shape,
    name="ring-fixed",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::identity(),
  )
  // 4. Rotating output ring gear (z = fixed_ring_length + ring_gap .. total_length).
  let r2_inner = match
    @gears.internal_involute_ring_profile(
      layout.output_ring_module_mm,
      layout.output_ring_teeth,
      params.pressure_angle_deg,
      backlash_mm=params.tolerance_mm,
    ) {
    Ok(pts) => pts
    Err(e) => return Err(e)
  }
  let r2_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * layout.output_ring_outer_radius_mm),
    params.output_ring_length_mm,
    holes=[@gears.arc_outline_runs(r2_inner)],
  ).as_shape()
  comp = comp.add_layer(
    r2_shape,
    name="ring-output",
    color=@cad.Rgb::new(0.18, 0.72, 0.45),
    placement=@common.Placement::translation(
      0.0,
      0.0,
      params.fixed_ring_length_mm + params.ring_gap_mm,
    ),
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
        depth_mm=params.fixed_ring_length_mm,
        description="fixed outer ring cylindrical seat",
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
        depth_mm=params.fixed_ring_length_mm,
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
        diameter_mm=2.0 * layout.output_ring_outer_radius_mm,
        description="rotating output ring face",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
