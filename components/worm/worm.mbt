///|
/// Parametric 90° right-angle worm gear drive (`gmlewis/step/components/worm`).
///
/// Models a high-ratio, optionally self-locking right-angle worm drive:
/// - **Worm wheel (`wheel`)**: exact involute gear on the `+Z` axis at `(0, 0, 0)`.
/// - **Worm shaft (`worm-core`, `worm-thread-*`)**: orthogonal input shaft
///   along `+X` at `y = -center_distance_mm, z = wheel_width_mm / 2`.
///
/// Computes exact reduction ratio (`wheel_teeth / worm_starts`), lead angle
/// `gamma = atan(m * z1 / (2 * r1))`, self-locking predicate
/// (`tan(gamma) < friction_coeff`), and sliding-mesh efficiency.

///|
const WORM_PI : Double = 3.141592653589793

///|
/// Input parameters for a 90° right-angle worm gear drive.
pub(all) struct WormGearParams {
  /// Axial module `m` in mm.
  module_mm : Double
  /// Number of worm thread starts (`z1 >= 1`; `1` is typically self-locking).
  worm_starts : Int32
  /// Number of teeth on the worm wheel (`z2 >= 12`).
  wheel_teeth : Int32
  /// Worm pitch radius `r1` in mm.
  worm_pitch_radius_mm : Double
  /// Axial length of the threaded worm shaft in mm.
  worm_length_mm : Double
  /// Axial face width of the worm wheel in mm.
  wheel_width_mm : Double
  /// Pressure angle in degrees (default `20.0`).
  pressure_angle_deg : Double
  /// Sliding friction coefficient `mu` (default `0.15` for steel-on-nylon/bronze).
  friction_coeff : Double
  /// Input bore radius of the worm shaft in mm.
  worm_bore_radius_mm : Double
  /// Output bore radius of the worm wheel in mm.
  wheel_bore_radius_mm : Double
  /// Radial backlash / clearance in mm.
  tolerance_mm : Double
}

///|
/// Builds and validates `WormGearParams`.
pub fn WormGearParams::new(
  module_mm~ : Double = 2.0,
  worm_starts~ : Int32 = 1,
  wheel_teeth~ : Int32 = 30,
  worm_pitch_radius_mm~ : Double = 10.0,
  worm_length_mm~ : Double = 36.0,
  wheel_width_mm~ : Double = 14.0,
  pressure_angle_deg~ : Double = 20.0,
  friction_coeff~ : Double = 0.15,
  worm_bore_radius_mm~ : Double = 4.0,
  wheel_bore_radius_mm~ : Double = 6.35,
  tolerance_mm~ : Double = @common.DEFAULT_GEAR_TOLERANCE_MM,
) -> Result[WormGearParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if worm_starts < 1 || worm_starts > 6 {
    return Err(@common.InvalidParameter("worm_starts must be in [1, 6]"))
  }
  if wheel_teeth < 12 {
    return Err(@common.InvalidParameter("wheel_teeth must be >= 12"))
  }
  if worm_pitch_radius_mm <= 1.25 * module_mm + 1.0 {
    return Err(
      @common.InvalidParameter("worm_pitch_radius_mm too small for module"),
    )
  }
  if worm_length_mm <= 0.0 || wheel_width_mm <= 0.0 {
    return Err(
      @common.InvalidParameter("worm_length_mm and wheel_width_mm must be > 0"),
    )
  }
  if friction_coeff < 0.0 {
    return Err(@common.InvalidParameter("friction_coeff must be >= 0"))
  }
  let worm_root = worm_pitch_radius_mm - 1.25 * module_mm
  if worm_bore_radius_mm <= 0.0 || worm_bore_radius_mm >= worm_root - 1.0 {
    return Err(
      @common.InvalidParameter("worm_bore_radius_mm does not fit worm root"),
    )
  }
  let wheel_root = module_mm * (wheel_teeth.to_double() / 2.0 - 1.25)
  if wheel_bore_radius_mm <= 0.0 || wheel_bore_radius_mm >= wheel_root - 1.5 {
    return Err(
      @common.InvalidParameter("wheel_bore_radius_mm does not fit wheel root"),
    )
  }
  Ok({
    module_mm,
    worm_starts,
    wheel_teeth,
    worm_pitch_radius_mm,
    worm_length_mm,
    wheel_width_mm,
    pressure_angle_deg,
    friction_coeff,
    worm_bore_radius_mm,
    wheel_bore_radius_mm,
    tolerance_mm,
  })
}

///|
/// Derived geometry, kinematics, and self-locking analysis for a worm drive.
pub(all) struct WormGearLayout {
  params : WormGearParams
  /// Reduction ratio `wheel_teeth / worm_starts`.
  reduction_ratio : Double
  /// Worm wheel pitch radius `r2 = m * z2 / 2`.
  wheel_pitch_radius_mm : Double
  /// Exact crossed-axis center distance `a = r1 + r2`.
  center_distance_mm : Double
  /// Axial pitch `p_x = pi * m`.
  axial_pitch_mm : Double
  /// Lead `L = pi * m * z1`.
  lead_mm : Double
  /// Lead angle `gamma` in degrees.
  lead_angle_deg : Double
  /// `true` when `tan(gamma) < friction_coeff` (cannot be backdriven).
  is_self_locking : Bool
  /// Estimated forward driving efficiency `tan(gamma) / tan(gamma + atan(mu))`.
  efficiency : Double
}

///|
/// Computes the derived layout and self-locking physics of a worm gear drive.
pub fn worm_gear_layout(params : WormGearParams) -> WormGearLayout {
  let reduction_ratio = params.wheel_teeth.to_double() /
    params.worm_starts.to_double()
  let wheel_pitch_radius_mm = params.module_mm *
    params.wheel_teeth.to_double() /
    2.0
  let center_distance_mm = params.worm_pitch_radius_mm + wheel_pitch_radius_mm
  let axial_pitch_mm = WORM_PI * params.module_mm
  let lead_mm = axial_pitch_mm * params.worm_starts.to_double()
  let tan_gamma = lead_mm / (2.0 * WORM_PI * params.worm_pitch_radius_mm)
  let gamma = @math.atan(tan_gamma)
  let lead_angle_deg = gamma * 180.0 / WORM_PI
  let is_self_locking = tan_gamma < params.friction_coeff
  let rho = @math.atan(params.friction_coeff)
  let efficiency = tan_gamma / @math.tan(gamma + rho)
  {
    params,
    reduction_ratio,
    wheel_pitch_radius_mm,
    center_distance_mm,
    axial_pitch_mm,
    lead_mm,
    lead_angle_deg,
    is_self_locking,
    efficiency,
  }
}

///|
/// Builds a parametric 90° right-angle worm gear drive as a `@common.Component`.
pub fn worm_gear_drive(
  params : WormGearParams,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = worm_gear_layout(params)
  let name = "worm-m\{@cad.fmt_double(params.module_mm, None)}-z\{params.worm_starts}-\{params.wheel_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=["worm-wheel-involute", "worm-shaft-core", "worm-thread-rings"],
    approximated=[
      @common.Approximation::new(
        feature="worm-thread-helix",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="discrete pitched thread flanges at axial pitch pi*m",
      ),
    ],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Worm drive \{@cad.fmt_double(layout.reduction_ratio, None)}:1 (m=\{@cad.fmt_double(params.module_mm, None)}, z1=\{params.worm_starts}, z2=\{params.wheel_teeth})",
      family="worm gear drive",
      size="m\{@cad.fmt_double(params.module_mm, None)}-z\{params.worm_starts}-\{params.wheel_teeth}",
      length_mm=params.wheel_width_mm,
      source="Parametric 90-deg right-angle worm gear drive.",
    ),
    description="90-degree right-angle worm gear drive with orthogonal input worm shaft and output worm wheel.",
    features~,
  )
  // 1. Worm wheel along +Z centered at (0, 0, 0).
  let wheel_outline = @gears.external_involute_outline(
    params.module_mm,
    params.wheel_teeth,
    params.pressure_angle_deg,
    backlash_mm=params.tolerance_mm,
  )
  let wheel_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(wheel_outline),
    params.wheel_width_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.wheel_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    wheel_shape,
    name="wheel",
    color=@cad.Rgb::blue(),
    placement=@common.Placement::identity(),
  )
  // 2. Worm shaft core along +X at y = -center_distance_mm, z = wheel_width/2.
  let worm_root_r = params.worm_pitch_radius_mm - 1.25 * params.module_mm
  let worm_outer_r = params.worm_pitch_radius_mm + params.module_mm
  let worm_core = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * worm_root_r),
    params.worm_length_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.worm_bore_radius_mm)],
  ).as_shape()
  let worm_x0 = -params.worm_length_mm / 2.0
  let worm_y = -layout.center_distance_mm
  let worm_z = params.wheel_width_mm / 2.0
  comp = comp.add_layer(
    worm_core,
    name="worm-core",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::at(worm_x0, worm_y, worm_z, ry=90.0),
  )
  // 3. Pitched worm thread flanges along the worm shaft.
  let thread_thick = layout.axial_pitch_mm * 0.45
  let num_threads = (params.worm_length_mm / layout.axial_pitch_mm).to_int()
  let thread_ring = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * worm_outer_r),
    thread_thick,
    holes=[@gears.arc_circle_segments(2.0 * worm_root_r * 0.98)],
  ).as_shape()
  for i in 0..<num_threads {
    let x = worm_x0 + (i.to_double() + 0.25) * layout.axial_pitch_mm
    if x + thread_thick <= params.worm_length_mm / 2.0 {
      comp = comp.add_layer(
        thread_ring,
        name="worm-thread-\{i + 1}",
        color=@cad.Rgb::new(0.95, 0.55, 0.12),
        placement=@common.Placement::at(x, worm_y, worm_z, ry=90.0),
      )
    }
  }
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "worm-input",
        placement=@common.Placement::translation(worm_x0, worm_y, worm_z),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.worm_bore_radius_mm,
        depth_mm=params.worm_length_mm,
        description="orthogonal worm input shaft bore (+X axis)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "wheel-output",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.wheel_bore_radius_mm,
        depth_mm=params.wheel_width_mm,
        description="worm wheel output bore (+Z axis)",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
