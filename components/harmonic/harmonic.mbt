///|
/// Parametric harmonic (strain-wave) gearbox stage (`gmlewis/step/components/harmonic`).
///
/// Models a cup-style strain-wave reducer along `+Z` (native print-flat frame,
/// or `+Y` when `y_up=true`):
///
/// - **Circular spline (`ring`)**: fixed rigid internal gear with `Z_c = Z_f + tooth_diff`
///   teeth integrated into the stage casing.
/// - **Flexspline (`flexspline-teeth`, `flexspline-cup`)**: thin-walled flexible
///   cup with `Z_f` external teeth. Supports both `deformed=true` (assembled
///   elliptical state, engaging at 0°/180° and clearing at 90°/270°) and
///   `deformed=false` (unstressed circular as-printed state).
/// - **Wave generator (`wave-generator`)**: radially symmetric 2-lobe elliptical
///   cam with input shaft bore. Because the ellipse is 180°-symmetric, its
///   center of mass stays on the rotation axis (inherently radially balanced).
///
/// Signed gear ratio (fixed circular spline, flexspline output):
///   `omega_out / omega_in = -tooth_diff / flexspline_teeth`
///   (e.g., 60/62 teeth -> `-30:1`, output rotates opposite to input).

///|
const HARM_PI : Double = 3.141592653589793

///|
const HARM_TWO_PI : Double = 6.283185307179586

///|
/// Input parameters for a parametric harmonic (strain-wave) gearbox stage.
pub(all) struct HarmonicParams {
  /// Gear module in mm (default `1.0`).
  module_mm : Double
  /// Flexspline external tooth count `Z_f` (must be even and `>= 30`).
  flexspline_teeth : Int32
  /// Tooth difference `Z_c - Z_f` (default `2` for a 2-lobe elliptical wave generator).
  tooth_diff : Int32
  /// Axial tooth engagement width in mm.
  gear_length_mm : Double
  /// Total axial length of the flexspline cup (tooth band + flexible diaphragm), in mm.
  cup_length_mm : Double
  /// Radial wall thickness of the thin flexspline cylinder below the tooth root, in mm.
  flex_wall_mm : Double
  /// Tooth pressure angle in degrees (default `20.0`).
  pressure_angle_deg : Double
  /// Radial wall thickness outside the circular spline root, in mm.
  outer_wall_mm : Double
  /// Input shaft bore radius in the wave generator hub, in mm.
  input_bore_radius_mm : Double
  /// Radial mesh and wave-generator clearance, in mm.
  tolerance_mm : Double
  /// If `true`, deform the flexspline onto the elliptical wave generator
  /// (assembled state); if `false`, keep it circular (as-printed state).
  deformed : Bool
}

///|
/// Builds and validates `HarmonicParams`.
pub fn HarmonicParams::new(
  module_mm~ : Double = 1.0,
  flexspline_teeth~ : Int32 = 60,
  tooth_diff~ : Int32 = 2,
  gear_length_mm~ : Double = 12.0,
  cup_length_mm~ : Double = 24.0,
  flex_wall_mm~ : Double = 1.2,
  pressure_angle_deg~ : Double = 20.0,
  outer_wall_mm~ : Double = 6.0,
  input_bore_radius_mm~ : Double = 4.1,
  tolerance_mm~ : Double = 0.1,
  deformed~ : Bool = true,
) -> Result[HarmonicParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if flexspline_teeth < 30 || flexspline_teeth % 2 != 0 {
    return Err(
      @common.InvalidParameter("flexspline_teeth must be even and >= 30"),
    )
  }
  if tooth_diff < 2 || tooth_diff % 2 != 0 {
    return Err(@common.InvalidParameter("tooth_diff must be even and >= 2"))
  }
  if gear_length_mm <= 0.0 {
    return Err(@common.InvalidParameter("gear_length_mm must be positive"))
  }
  if cup_length_mm < gear_length_mm + 4.0 {
    return Err(
      @common.InvalidParameter(
        "cup_length_mm must be >= gear_length_mm + 4.0 mm for flexspline compliance",
      ),
    )
  }
  if flex_wall_mm <= 0.2 {
    return Err(@common.InvalidParameter("flex_wall_mm must be > 0.2 mm"))
  }
  if pressure_angle_deg < 10.0 || pressure_angle_deg > 35.0 {
    return Err(
      @common.InvalidParameter("pressure_angle_deg must be in [10, 35]"),
    )
  }
  if outer_wall_mm <= 0.0 {
    return Err(@common.InvalidParameter("outer_wall_mm must be positive"))
  }
  if input_bore_radius_mm <= 0.0 {
    return Err(
      @common.InvalidParameter("input_bore_radius_mm must be positive"),
    )
  }
  if tolerance_mm < 0.0 {
    return Err(@common.InvalidParameter("tolerance_mm must be >= 0"))
  }
  // Check that the wave generator minor radius leaves sufficient hub wall
  // around the input shaft bore.
  let flex_pitch_r = module_mm * flexspline_teeth.to_double() / 2.0
  let w0 = module_mm * tooth_diff.to_double() / 2.0
  let flex_root_r = flex_pitch_r - 1.0 * module_mm
  let flex_inner_r = flex_root_r - flex_wall_mm
  let wg_minor_r = flex_inner_r - w0 - tolerance_mm
  if wg_minor_r <= input_bore_radius_mm + 2.0 {
    return Err(
      @common.InvalidParameter(
        "wave generator minor radius (\{wg_minor_r} mm) is too small for input_bore_radius_mm (\{input_bore_radius_mm} mm)",
      ),
    )
  }
  Ok({
    module_mm,
    flexspline_teeth,
    tooth_diff,
    gear_length_mm,
    cup_length_mm,
    flex_wall_mm,
    pressure_angle_deg,
    outer_wall_mm,
    input_bore_radius_mm,
    tolerance_mm,
    deformed,
  })
}

///|
/// Derived geometric dimensions of a harmonic drive stage.
pub(all) struct HarmonicLayout {
  params : HarmonicParams
  /// Circular spline internal tooth count (`flexspline_teeth + tooth_diff`).
  circular_spline_teeth : Int32
  /// Signed reduction ratio (`-flexspline_teeth / tooth_diff`).
  signed_reduction : Double
  /// Reduction ratio magnitude (`flexspline_teeth / tooth_diff`).
  reduction_ratio : Double
  /// Stubbed tooth addendum (`0.75 * m`) for clean minor-axis tip clearance.
  addendum_mm : Double
  /// Tooth dedendum (`1.0 * m`).
  dedendum_mm : Double
  /// Unstressed flexspline pitch radius (`m * Z_f / 2`).
  flex_pitch_radius_mm : Double
  /// Flexspline unstressed root radius.
  flex_root_radius_mm : Double
  /// Flexspline unstressed tip radius.
  flex_tip_radius_mm : Double
  /// Flexspline unstressed inner bore radius.
  flex_inner_radius_mm : Double
  /// Circular spline pitch radius (`m * Z_c / 2`).
  circ_pitch_radius_mm : Double
  /// Circular spline inner tip radius.
  circ_tip_radius_mm : Double
  /// Circular spline outer root radius.
  circ_root_radius_mm : Double
  /// Circular spline outer casing radius.
  circ_outer_radius_mm : Double
  /// Elliptical radial deflection amplitude `w0 = m * tooth_diff / 2`.
  radial_deflection_mm : Double
  /// Wave generator major outer radius.
  wave_gen_major_radius_mm : Double
  /// Wave generator minor outer radius.
  wave_gen_minor_radius_mm : Double
  /// Total axial length of the harmonic stage (`cup_length_mm`).
  total_length_mm : Double
}

///|
/// Computes the derived layout of a harmonic drive stage.
pub fn harmonic_layout(params : HarmonicParams) -> HarmonicLayout {
  let circular_spline_teeth = params.flexspline_teeth + params.tooth_diff
  let reduction_ratio = params.flexspline_teeth.to_double() /
    params.tooth_diff.to_double()
  let signed_reduction = -reduction_ratio
  let m = params.module_mm
  let addendum_mm = 0.75 * m
  let dedendum_mm = 1.0 * m
  let flex_pitch_radius_mm = m * params.flexspline_teeth.to_double() / 2.0
  let flex_root_radius_mm = flex_pitch_radius_mm - dedendum_mm
  let flex_tip_radius_mm = flex_pitch_radius_mm +
    addendum_mm -
    params.tolerance_mm
  let flex_inner_radius_mm = flex_root_radius_mm - params.flex_wall_mm
  let circ_pitch_radius_mm = m * circular_spline_teeth.to_double() / 2.0
  let circ_tip_radius_mm = circ_pitch_radius_mm -
    addendum_mm +
    params.tolerance_mm
  let circ_root_radius_mm = circ_pitch_radius_mm + dedendum_mm
  let circ_outer_radius_mm = circ_root_radius_mm + params.outer_wall_mm
  let radial_deflection_mm = m * params.tooth_diff.to_double() / 2.0
  let wave_gen_major_radius_mm = flex_inner_radius_mm +
    radial_deflection_mm -
    params.tolerance_mm
  let wave_gen_minor_radius_mm = flex_inner_radius_mm -
    radial_deflection_mm -
    params.tolerance_mm
  {
    params,
    circular_spline_teeth,
    signed_reduction,
    reduction_ratio,
    addendum_mm,
    dedendum_mm,
    flex_pitch_radius_mm,
    flex_root_radius_mm,
    flex_tip_radius_mm,
    flex_inner_radius_mm,
    circ_pitch_radius_mm,
    circ_tip_radius_mm,
    circ_root_radius_mm,
    circ_outer_radius_mm,
    radial_deflection_mm,
    wave_gen_major_radius_mm,
    wave_gen_minor_radius_mm,
    total_length_mm: params.cup_length_mm,
  }
}

///|
/// Kinematic state of the harmonic stage for a given input angle.
pub(all) struct HarmonicKinematics {
  /// Wave generator (input) angle in radians.
  wave_gen_rad : Double
  /// Flexspline (output) angle in radians (`-wave_gen_rad * tooth_diff / Z_f`).
  output_rad : Double
}

///|
/// Evaluates the kinematic state of the harmonic drive for a given `input_deg`.
pub fn harmonic_kinematics(
  layout : HarmonicLayout,
  input_deg : Double,
) -> HarmonicKinematics {
  let wave_gen_rad = input_deg * HARM_PI / 180.0
  let output_rad = -wave_gen_rad / layout.reduction_ratio
  { wave_gen_rad, output_rad, }
}

///|
fn harm_deform_polar(
  r : Double,
  psi : Double,
  r_pitch : Double,
  w0 : Double,
  wave_gen_rad : Double,
  lobes : Int32,
) -> (Double, Double) {
  let k = lobes.to_double()
  let rel = psi - wave_gen_rad
  let r_def = r + w0 * @math.cos(k * rel)
  // First-order inextensible neutral-line tangential shift: dv/dpsi + w = 0.
  let psi_def = psi - w0 / (k * r_pitch) * @math.sin(k * rel)
  (r_def * @math.cos(psi_def), r_def * @math.sin(psi_def))
}

///|
/// Generates the closed 2D CCW tooth outline `(x, y)` of the flexspline.
/// When `deformed=true`, applies the inextensible elliptical strain-wave
/// deformation aligned with `wave_gen_rad`.
pub fn harmonic_flexspline_outline(
  layout : HarmonicLayout,
  wave_gen_rad~ : Double = 0.0,
  deformed~ : Bool = true,
) -> Array[(Double, Double)] {
  let z = layout.params.flexspline_teeth
  let pitch_ang = HARM_TWO_PI / z.to_double()
  let tan_a = @math.tan(layout.params.pressure_angle_deg * HARM_PI / 180.0)
  // Tooth angular half-width at pitch, tip, and root.
  let half_pitch = pitch_ang * 0.24
  let d_tip = layout.addendum_mm * tan_a / layout.flex_pitch_radius_mm
  let d_root = layout.dedendum_mm * tan_a / layout.flex_pitch_radius_mm
  let half_tip = if half_pitch - d_tip > pitch_ang * 0.06 {
    half_pitch - d_tip
  } else {
    pitch_ang * 0.06
  }
  let half_root = if half_pitch + d_root < pitch_ang * 0.44 {
    half_pitch + d_root
  } else {
    pitch_ang * 0.44
  }
  let r_root = layout.flex_root_radius_mm
  let r_tip = layout.flex_tip_radius_mm
  let r_pitch = layout.flex_pitch_radius_mm
  let w0 = layout.radial_deflection_mm
  let lobes = layout.params.tooth_diff
  let pts : Array[(Double, Double)] = []
  for i in 0..<z {
    let center = pitch_ang * i.to_double()
    let samples : Array[(Double, Double)] = [
      (r_root, center - half_root),
      (r_tip, center - half_tip),
      (r_tip, center + half_tip),
      (r_root, center + half_root),
    ]
    for s in samples {
      let (r, psi) = s
      let pt = if deformed {
        harm_deform_polar(r, psi, r_pitch, w0, wave_gen_rad, lobes)
      } else {
        (r * @math.cos(psi), r * @math.sin(psi))
      }
      pts.push(pt)
    }
  }
  pts
}

///|
/// Generates the closed 2D CCW internal tooth outline `(x, y)` of the rigid
/// circular spline (for use as a CCW hole in `ExtrudedArcProfile`).
pub fn harmonic_circular_spline_inner_outline(
  layout : HarmonicLayout,
) -> Array[(Double, Double)] {
  let z = layout.circular_spline_teeth
  let pitch_ang = HARM_TWO_PI / z.to_double()
  let tan_a = @math.tan(layout.params.pressure_angle_deg * HARM_PI / 180.0)
  // Space centered at angle = 0 so a flexspline tooth at angle = 0 meshes
  // directly into a circular spline tooth space at the major axis.
  let half_space_pitch = pitch_ang * 0.26
  let d_tip = layout.addendum_mm * tan_a / layout.circ_pitch_radius_mm
  let d_root = layout.dedendum_mm * tan_a / layout.circ_pitch_radius_mm
  let half_space_root = if half_space_pitch - d_root > pitch_ang * 0.08 {
    half_space_pitch - d_root
  } else {
    pitch_ang * 0.08
  }
  let half_space_tip = if half_space_pitch + d_tip < pitch_ang * 0.44 {
    half_space_pitch + d_tip
  } else {
    pitch_ang * 0.44
  }
  let r_tip = layout.circ_tip_radius_mm
  let r_root = layout.circ_root_radius_mm
  let pts : Array[(Double, Double)] = []
  for i in 0..<z {
    let center = pitch_ang * i.to_double()
    let samples : Array[(Double, Double)] = [
      (r_tip, center - half_space_tip),
      (r_root, center - half_space_root),
      (r_root, center + half_space_root),
      (r_tip, center + half_space_tip),
    ]
    for s in samples {
      pts.push((s.0 * @math.cos(s.1), s.0 * @math.sin(s.1)))
    }
  }
  pts
}

///|
/// Generates the closed 2D CCW elliptical outline `(x, y)` of the wave
/// generator cam at `wave_gen_rad`.
pub fn harmonic_wave_generator_outline(
  layout : HarmonicLayout,
  wave_gen_rad~ : Double = 0.0,
  num_points~ : Int32 = 72,
) -> Array[(Double, Double)] {
  let n = if num_points < 24 { 24 } else { num_points }
  let r_mean = layout.flex_inner_radius_mm - layout.params.tolerance_mm
  let w0 = layout.radial_deflection_mm
  let k = layout.params.tooth_diff.to_double()
  let pts : Array[(Double, Double)] = []
  for i in 0..<n {
    let psi = HARM_TWO_PI * i.to_double() / n.to_double()
    let r = r_mean + w0 * @math.cos(k * (psi - wave_gen_rad))
    pts.push((r * @math.cos(psi), r * @math.sin(psi)))
  }
  pts
}

///|
fn harm_circle_ccw(radius : Double) -> Array[@cad.ProfileSegment] {
  @gears.arc_circle_segments(2.0 * radius)
}

///|
fn harm_ellipse_ring_ccw(
  layout : HarmonicLayout,
  wave_gen_rad : Double,
  deformed : Bool,
  num_points : Int32,
) -> Array[(Double, Double)] {
  let n = if num_points < 24 { 24 } else { num_points }
  let r_in = layout.flex_inner_radius_mm
  let w0 = layout.radial_deflection_mm
  let k = layout.params.tooth_diff.to_double()
  let pts : Array[(Double, Double)] = []
  for i in 0..<n {
    let psi = HARM_TWO_PI * i.to_double() / n.to_double()
    let r = if deformed {
      r_in + w0 * @math.cos(k * (psi - wave_gen_rad))
    } else {
      r_in
    }
    pts.push((r * @math.cos(psi), r * @math.sin(psi)))
  }
  pts
}

///|
/// Builds a complete parametric harmonic (strain-wave) gearbox stage as a
/// `@common.Component` with named layers (`ring`, `flexspline-teeth`,
/// `flexspline-cup`, `wave-generator`) and mate connectors.
///
/// The native frame has the shaft along `+Z` (print-flat) from `z = 0` to
/// `z = layout.total_length_mm`. Pass `y_up=true` to rotate to `+Y` up.
pub fn harmonic_gearbox(
  params : HarmonicParams,
  input_deg~ : Double = 0.0,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = harmonic_layout(params)
  let kin = harmonic_kinematics(layout, input_deg)
  let name = "harmonic-m\{@cad.fmt_double(params.module_mm, None)}-zf\{params.flexspline_teeth}-zc\{layout.circular_spline_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "circular-spline-ring",
      if params.deformed {
        "deformed-elliptical-flexspline"
      } else {
        "unstressed-circular-flexspline"
      },
      "flexspline-cup",
      "elliptical-wave-generator",
    ],
    approximated=[
      @common.Approximation::new(
        feature="harmonic-tooth-profile",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=0.0,
        control="stubbed 20-deg harmonic tooth flanks with inextensible strain-wave ellipse mapping",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="wave-generator-bearing-balls",
        reason="thin-section flexible bearing is represented by the elliptical cam envelope",
      ),
    ],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Harmonic drive \{@cad.fmt_double(layout.reduction_ratio, None)}:1 (m=\{@cad.fmt_double(params.module_mm, None)}, Zf=\{params.flexspline_teeth}, Zc=\{layout.circular_spline_teeth})",
      family="harmonic gearbox",
      size="m\{@cad.fmt_double(params.module_mm, None)}-zf\{params.flexspline_teeth}",
      length_mm=layout.total_length_mm,
      source="Parametric strain-wave (harmonic) reducer with circular spline, cup flexspline, and radially balanced elliptical wave generator.",
    ),
    description="Parametric harmonic (strain-wave) drive stage: fixed circular spline, thin-walled flexspline cup (deformed elliptical or circular as-printed), and symmetric 2-lobe elliptical wave generator.",
    features~,
  )
  // 1. Rigid circular spline ring (spans the tooth engagement zone z = 0..gear_length).
  let circ_inner = harmonic_circular_spline_inner_outline(layout)
  let ring_shape = @cad.ExtrudedArcProfile::new(
    harm_circle_ccw(layout.circ_outer_radius_mm),
    params.gear_length_mm,
    holes=[@gears.arc_outline_runs(circ_inner)],
  ).as_shape()
  comp = comp.add_layer(
    ring_shape,
    name="ring",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::identity(),
  )
  // 2. Flexspline toothed band (z = 0..gear_length).
  let flex_outer = harmonic_flexspline_outline(
    layout,
    wave_gen_rad=kin.wave_gen_rad,
    deformed=params.deformed,
  )
  let flex_inner = harm_ellipse_ring_ccw(
    layout,
    kin.wave_gen_rad,
    params.deformed,
    72,
  )
  let flex_teeth_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(flex_outer),
    params.gear_length_mm,
    holes=[@gears.arc_outline_runs(flex_inner)],
  ).as_shape()
  comp = comp.add_layer(
    flex_teeth_shape,
    name="flexspline-teeth",
    color=@cad.Rgb::blue(),
    placement=@common.Placement::identity(),
  )
  // 3. Flexspline thin-walled cup sleeve + output diaphragm (z = gear_length..cup_length).
  let cup_sleeve_len = params.cup_length_mm - params.gear_length_mm
  let diaphragm_t = 3.0
  let sleeve_h = if cup_sleeve_len > diaphragm_t + 1.0 {
    cup_sleeve_len - diaphragm_t
  } else {
    1.0
  }
  let cup_sleeve_shape = @cad.ExtrudedArcProfile::new(
    harm_circle_ccw(layout.flex_root_radius_mm),
    sleeve_h,
    holes=[harm_circle_ccw(layout.flex_inner_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    cup_sleeve_shape,
    name="flexspline-cup",
    color=@cad.Rgb::new(0.20, 0.55, 0.90),
    placement=@common.Placement::translation(0.0, 0.0, params.gear_length_mm),
  )
  let diaphragm_shape = @cad.Cylinder::new(
    2.0 * layout.flex_root_radius_mm,
    diaphragm_t,
  )
  comp = comp.add_layer(
    diaphragm_shape,
    name="flexspline-diaphragm",
    color=@cad.Rgb::new(0.15, 0.45, 0.80),
    placement=@common.Placement::translation(
      0.0,
      0.0,
      params.gear_length_mm + sleeve_h,
    ),
  )
  // 4. Elliptical wave generator cam (z = 0..gear_length).
  let wg_outer = harmonic_wave_generator_outline(
    layout,
    wave_gen_rad=kin.wave_gen_rad,
  )
  let wg_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_outline_runs(wg_outer),
    params.gear_length_mm,
    holes=[harm_circle_ccw(params.input_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    wg_shape,
    name="wave-generator",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::identity(),
  )
  // Mate connectors along +Z.
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-outer-seat",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=2.0 * layout.circ_outer_radius_mm,
        depth_mm=params.gear_length_mm,
        description="circular spline outer cylindrical seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-a",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * layout.circ_outer_radius_mm,
        description="input-side face of circular spline (z = 0)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "ring-face-b",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          params.gear_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=2.0 * layout.circ_outer_radius_mm,
        description="output-side face of circular spline (z = gear_length)",
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
        depth_mm=params.gear_length_mm,
        description="wave generator input shaft bore",
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
        diameter_mm=2.0 * layout.flex_root_radius_mm,
        description="flexspline output diaphragm face",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
