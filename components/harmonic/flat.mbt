///|
/// Compound / split-ring (flat/pancake) harmonic drive (`flat_harmonic_gearbox`).
///
/// Unlike a cup-style harmonic drive (which requires a long compliant cup),
/// a flat/pancake harmonic drive uses a short floating flex-ring spanning two
/// coaxial rigid internal rings:
/// - **Fixed circular spline (`ring-fixed`)**: `Z_c1 = Z_f + tooth_diff` teeth.
/// - **Output dynamic spline (`ring-output`)**: `Z_c2 = Z_f` teeth (acts as a
///   1:1 spline coupling to the floating flex-ring, outputting `-Z_f / tooth_diff`).

///|
/// Input parameters for a flat / pancake (split-ring) harmonic stage.
pub(all) struct FlatHarmonicParams {
  module_mm : Double
  flexspline_teeth : Int32
  tooth_diff : Int32
  /// Axial width of each circular spline ring (total flex-ring width is `2 * ring_length + ring_gap`).
  ring_length_mm : Double
  /// Axial gap between the fixed circular spline and output dynamic spline.
  ring_gap_mm : Double
  flex_wall_mm : Double
  pressure_angle_deg : Double
  outer_wall_mm : Double
  input_bore_radius_mm : Double
  tolerance_mm : Double
  deformed : Bool
}

///|
/// Builds and validates `FlatHarmonicParams`.
pub fn FlatHarmonicParams::new(
  module_mm~ : Double = 1.0,
  flexspline_teeth~ : Int32 = 60,
  tooth_diff~ : Int32 = 2,
  ring_length_mm~ : Double = 7.0,
  ring_gap_mm~ : Double = 1.0,
  flex_wall_mm~ : Double = 1.2,
  pressure_angle_deg~ : Double = 20.0,
  outer_wall_mm~ : Double = 6.0,
  input_bore_radius_mm~ : Double = 4.1,
  tolerance_mm~ : Double = @common.DEFAULT_GEAR_TOLERANCE_MM,
  deformed~ : Bool = true,
) -> Result[FlatHarmonicParams, @common.SpecError] {
  // Reuse HarmonicParams validation by checking with an equivalent cup length.
  match
    HarmonicParams::new(
      module_mm~,
      flexspline_teeth~,
      tooth_diff~,
      gear_length_mm=ring_length_mm,
      cup_length_mm=ring_length_mm + 6.0,
      flex_wall_mm~,
      pressure_angle_deg~,
      outer_wall_mm~,
      input_bore_radius_mm~,
      tolerance_mm~,
      deformed~,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if ring_gap_mm < 0.0 {
    return Err(@common.InvalidParameter("ring_gap_mm must be >= 0"))
  }
  Ok({
    module_mm,
    flexspline_teeth,
    tooth_diff,
    ring_length_mm,
    ring_gap_mm,
    flex_wall_mm,
    pressure_angle_deg,
    outer_wall_mm,
    input_bore_radius_mm,
    tolerance_mm,
    deformed,
  })
}

///|
/// Derived layout for a flat / pancake (split-ring) harmonic stage.
pub(all) struct FlatHarmonicLayout {
  params : FlatHarmonicParams
  base : HarmonicLayout
  /// Total pancake axial height (`2 * ring_length_mm + ring_gap_mm`).
  total_length_mm : Double
  /// Outer radius of the rotating output dynamic spline ring.
  output_ring_outer_radius_mm : Double
}

///|
/// Computes the derived layout of a flat / pancake harmonic stage.
pub fn flat_harmonic_layout(params : FlatHarmonicParams) -> FlatHarmonicLayout {
  let hp : HarmonicParams = {
    module_mm: params.module_mm,
    flexspline_teeth: params.flexspline_teeth,
    tooth_diff: params.tooth_diff,
    gear_length_mm: params.ring_length_mm,
    cup_length_mm: params.ring_length_mm * 2.0 + params.ring_gap_mm,
    flex_wall_mm: params.flex_wall_mm,
    pressure_angle_deg: params.pressure_angle_deg,
    outer_wall_mm: params.outer_wall_mm,
    input_bore_radius_mm: params.input_bore_radius_mm,
    tolerance_mm: params.tolerance_mm,
    deformed: params.deformed,
  }
  let base = harmonic_layout(hp)
  let total_length_mm = 2.0 * params.ring_length_mm + params.ring_gap_mm
  let output_ring_outer_radius_mm = base.circ_root_radius_mm + 3.5
  { params, base, total_length_mm, output_ring_outer_radius_mm, }
}

///|
/// Builds a flat / pancake (split-ring) harmonic drive stage along `+Z`
/// (layers: `ring-fixed`, `ring-output`, `flexspline-ring`, `wave-generator`).
pub fn flat_harmonic_gearbox(
  params : FlatHarmonicParams,
  input_deg~ : Double = 0.0,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let fl = flat_harmonic_layout(params)
  let base = fl.base
  let kin = harmonic_kinematics(base, input_deg)
  let name = "flat-harmonic-m\{@cad.fmt_double(params.module_mm, None)}-zf\{params.flexspline_teeth}-zc\{base.circular_spline_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "fixed-circular-spline", "output-dynamic-spline", "floating-flex-ring", "elliptical-wave-generator",
    ],
    approximated=[],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Flat pancake harmonic \{@cad.fmt_double(base.reduction_ratio, None)}:1 (Zf=\{params.flexspline_teeth}, Zc=\{base.circular_spline_teeth})",
      family="flat harmonic gearbox",
      size="m\{@cad.fmt_double(params.module_mm, None)}-zf\{params.flexspline_teeth}-flat",
      length_mm=fl.total_length_mm,
      source="Parametric split-ring pancake harmonic drive.",
    ),
    description="Compact pancake (split-ring) harmonic drive with fixed circular spline, rotating output dynamic spline, floating flex-ring, and elliptical wave generator.",
    features~,
  )
  // 1. Fixed circular spline (z = 0..ring_length).
  let circ_inner = harmonic_circular_spline_inner_outline(base)
  let fixed_ring_shape = @cad.ExtrudedArcProfile::new(
    harm_circle_ccw(base.circ_outer_radius_mm),
    params.ring_length_mm,
    holes=[@gears.arc_outline_runs(circ_inner)],
  ).as_shape()
  comp = comp.add_layer(
    fixed_ring_shape,
    name="ring-fixed",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::identity(),
  )
  // 2. Output dynamic spline (z = ring_length + ring_gap .. total_length).
  let dyn_layout : HarmonicLayout = {
    ..base,
    circular_spline_teeth: params.flexspline_teeth,
    circ_pitch_radius_mm: base.flex_pitch_radius_mm + base.radial_deflection_mm,
  }
  let dyn_inner = harmonic_circular_spline_inner_outline(dyn_layout)
  let out_ring_shape = @cad.ExtrudedArcProfile::new(
    harm_circle_ccw(fl.output_ring_outer_radius_mm),
    params.ring_length_mm,
    holes=[@gears.arc_outline_runs(dyn_inner)],
  ).as_shape()
  comp = comp.add_layer(
    out_ring_shape,
    name="ring-output",
    color=@cad.Rgb::new(0.18, 0.72, 0.45),
    placement=@common.Placement::translation(
      0.0,
      0.0,
      params.ring_length_mm + params.ring_gap_mm,
    ),
  )
  // 3. Floating flex-ring spanning both splines (z = 0..total_length).
  let flex_outer = harmonic_flexspline_outline(
    base,
    wave_gen_rad=kin.wave_gen_rad,
    deformed=params.deformed,
  )
  let flex_inner = harm_ellipse_ring_ccw(
    base,
    kin.wave_gen_rad,
    params.deformed,
    72,
  )
  let flex_ring_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(flex_outer),
    fl.total_length_mm,
    holes=[@gears.arc_outline_runs(flex_inner)],
  ).as_shape()
  comp = comp.add_layer(
    flex_ring_shape,
    name="flexspline-ring",
    color=@cad.Rgb::blue(),
    placement=@common.Placement::identity(),
  )
  // 4. Elliptical wave generator spanning full pancake width.
  let wg_outer = harmonic_wave_generator_outline(
    base,
    wave_gen_rad=kin.wave_gen_rad,
  )
  let wg_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(wg_outer),
    fl.total_length_mm,
    holes=[harm_circle_ccw(params.input_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    wg_shape,
    name="wave-generator",
    color=@cad.Rgb::orange(),
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
        diameter_mm=2.0 * base.circ_outer_radius_mm,
        depth_mm=params.ring_length_mm,
        description="fixed circular spline outer seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "input-bore",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.input_bore_radius_mm,
        depth_mm=fl.total_length_mm,
        description="wave generator input bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-face",
        placement=@common.Placement::translation(0.0, 0.0, fl.total_length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * fl.output_ring_outer_radius_mm,
        description="output dynamic spline face",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
