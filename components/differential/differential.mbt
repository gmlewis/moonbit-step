///|
/// Parametric 2-motor, 2-DOF bevel gear differential (`gmlewis/step/components/differential`).
///
/// Widely used in robotics wrists, ankles, and hips so two stationary motors
/// share their combined torque across both pitch and roll axes:
/// - **Input bevel A (`input-a`)** and **Input bevel B (`input-b`)**: opposing
///   coaxial bevel gears along the `±X` axis (`input_teeth`).
/// - **Output bevel (`output-bevel`)**: perpendicular bevel gear along `+Z`
///   (`output_teeth`) carried by the rotating pitch spider.
///
/// Exact 2-DOF kinematics:
///   `pitch = (theta_a + theta_b) / 2`
///   `roll  = (Z_in / Z_out) * (theta_a - theta_b) / 2`

///|
/// Input parameters for a 2-motor, 2-DOF bevel gear differential.
pub(all) struct BevelDifferentialParams {
  /// Bevel gear module in mm.
  module_mm : Double
  /// Tooth count of each opposing input bevel gear (`Z_in >= 12`).
  input_teeth : Int32
  /// Tooth count of the perpendicular output bevel gear (`Z_out >= 12`).
  output_teeth : Int32
  /// Bevel gear face width in mm.
  face_width_mm : Double
  /// Bore diameter of each input bevel gear in mm.
  input_bore_diameter_mm : Double
  /// Bore diameter of the output bevel gear in mm.
  output_bore_diameter_mm : Double
  /// Backlash in mm.
  backlash_mm : Double
}

///|
/// Builds and validates `BevelDifferentialParams`.
pub fn BevelDifferentialParams::new(
  module_mm~ : Double = 2.0,
  input_teeth~ : Int32 = 20,
  output_teeth~ : Int32 = 20,
  face_width_mm~ : Double = 8.0,
  input_bore_diameter_mm~ : Double = 8.0,
  output_bore_diameter_mm~ : Double = 8.0,
  backlash_mm~ : Double = 0.1,
) -> Result[BevelDifferentialParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if input_teeth < 12 || output_teeth < 12 {
    return Err(
      @common.InvalidParameter("input_teeth and output_teeth must be >= 12"),
    )
  }
  if face_width_mm <= 0.0 {
    return Err(@common.InvalidParameter("face_width_mm must be positive"))
  }
  if input_bore_diameter_mm < 0.0 || output_bore_diameter_mm < 0.0 {
    return Err(@common.InvalidParameter("bore diameters must be >= 0"))
  }
  Ok({
    module_mm,
    input_teeth,
    output_teeth,
    face_width_mm,
    input_bore_diameter_mm,
    output_bore_diameter_mm,
    backlash_mm,
  })
}

///|
/// Derived geometry and 2-DOF coupling ratios for a bevel differential.
pub(all) struct BevelDifferentialLayout {
  params : BevelDifferentialParams
  /// Pitch radius of each input bevel gear (`m * Z_in / 2`).
  input_pitch_radius_mm : Double
  /// Pitch radius of the output bevel gear (`m * Z_out / 2`).
  output_pitch_radius_mm : Double
  /// Roll gear ratio `Z_out / Z_in` (so `roll = (theta_a - theta_b) / (2 * roll_ratio)`).
  roll_ratio : Double
  /// Mounting distance from the cone apex to the back face of each input bevel.
  input_apex_offset_mm : Double
  /// Mounting distance from the cone apex to the back face of the output bevel.
  output_apex_offset_mm : Double
}

///|
/// Computes the derived layout of a 2-DOF bevel differential.
pub fn bevel_differential_layout(
  params : BevelDifferentialParams,
) -> BevelDifferentialLayout {
  let r_in = params.module_mm * params.input_teeth.to_double() / 2.0
  let r_out = params.module_mm * params.output_teeth.to_double() / 2.0
  let roll_ratio = params.output_teeth.to_double() /
    params.input_teeth.to_double()
  {
    params,
    input_pitch_radius_mm: r_in,
    output_pitch_radius_mm: r_out,
    roll_ratio,
    input_apex_offset_mm: r_out,
    output_apex_offset_mm: r_in,
  }
}

///|
/// Forward kinematics: maps motor angles `(theta_a_rad, theta_b_rad)` to
/// `(pitch_rad, roll_rad)`.
pub fn differential_forward_kinematics(
  layout : BevelDifferentialLayout,
  theta_a_rad : Double,
  theta_b_rad : Double,
) -> (Double, Double) {
  let pitch = (theta_a_rad + theta_b_rad) / 2.0
  let roll = (theta_a_rad - theta_b_rad) / (2.0 * layout.roll_ratio)
  (pitch, roll)
}

///|
/// Inverse kinematics: maps desired `(pitch_rad, roll_rad)` to motor angles
/// `(theta_a_rad, theta_b_rad)`.
pub fn differential_inverse_kinematics(
  layout : BevelDifferentialLayout,
  pitch_rad : Double,
  roll_rad : Double,
) -> (Double, Double) {
  let delta = layout.roll_ratio * roll_rad
  (pitch_rad + delta, pitch_rad - delta)
}

///|
/// Builds a parametric 2-DOF bevel gear differential as a `@common.Component`
/// centered at the cone intersection `(0, 0, 0)`:
/// - Input bevel A along `+X` (at `x = -output_pitch_radius`)
/// - Input bevel B along `-X` (at `x = +output_pitch_radius`)
/// - Output bevel along `+Z` (at `z = +input_pitch_radius`)
/// - Pitch spider block connecting the axes.
pub fn bevel_differential(
  params : BevelDifferentialParams,
  detail~ : @common.DetailLevel = @common.DetailLevel::Simplified,
) -> Result[@common.Component, @common.SpecError] {
  let layout = bevel_differential_layout(params)
  let in_params = match
    @gears.BevelGearParams::new(
      module_mm=params.module_mm,
      teeth=params.input_teeth,
      mate_teeth=params.output_teeth,
      face_width_mm=params.face_width_mm,
      bore_diameter_mm=params.input_bore_diameter_mm,
      backlash_mm=params.backlash_mm,
      involute_points=6,
      arc_points=4,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let out_params = match
    @gears.BevelGearParams::new(
      module_mm=params.module_mm,
      teeth=params.output_teeth,
      mate_teeth=params.input_teeth,
      face_width_mm=params.face_width_mm,
      bore_diameter_mm=params.output_bore_diameter_mm,
      backlash_mm=params.backlash_mm,
      involute_points=6,
      arc_points=4,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let bevel_a = match
    @gears.bevel_gear(in_params, detail~, color=@cad.Rgb::orange()) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let bevel_b = match
    @gears.bevel_gear(in_params, detail~, color=@cad.Rgb::new(0.90, 0.40, 0.10)) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let bevel_out = match
    @gears.bevel_gear(out_params, detail~, color=@cad.Rgb::blue()) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let name = "bevel-diff-m\{@cad.fmt_double(params.module_mm, None)}-z\{params.input_teeth}-\{params.output_teeth}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "input-bevel-a", "input-bevel-b", "output-bevel", "pitch-spider-hub",
    ],
    approximated=[],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="2-DOF bevel differential (m=\{@cad.fmt_double(params.module_mm, None)}, Zin=\{params.input_teeth}, Zout=\{params.output_teeth})",
      family="bevel differential",
      size="m\{@cad.fmt_double(params.module_mm, None)}-\{params.input_teeth}-\{params.output_teeth}",
      length_mm=2.0 * layout.input_apex_offset_mm,
      source="Parametric 2-motor, 2-DOF bevel gear differential for robotics wrists, ankles, and hips.",
    ),
    description="2-motor, 2-DOF bevel gear differential sharing motor torque across pitch and roll axes.",
    features~,
  )
  // Place input bevel A at x = -output_pitch_radius facing +X.
  for layer in bevel_a.layers() {
    comp = comp.add_layer(
      layer.shape,
      name="input-a-" + layer.name,
      color=layer.color,
      placement=@common.Placement::compose(
        @common.Placement::at(-layout.input_apex_offset_mm, 0.0, 0.0, ry=90.0),
        layer.placement,
      ),
    )
  }
  // Place input bevel B at x = +output_pitch_radius facing -X.
  for layer in bevel_b.layers() {
    comp = comp.add_layer(
      layer.shape,
      name="input-b-" + layer.name,
      color=layer.color,
      placement=@common.Placement::compose(
        @common.Placement::at(layout.input_apex_offset_mm, 0.0, 0.0, ry=-90.0),
        layer.placement,
      ),
    )
  }
  // Place output bevel at z = +input_pitch_radius facing -Z.
  for layer in bevel_out.layers() {
    comp = comp.add_layer(
      layer.shape,
      name="output-" + layer.name,
      color=layer.color,
      placement=@common.Placement::compose(
        @common.Placement::at(0.0, 0.0, layout.output_apex_offset_mm, rx=180.0),
        layer.placement,
      ),
    )
  }
  // Central pitch spider hub tying the bevel axes together at the cone center.
  let spider_r = if params.input_bore_diameter_mm > 4.0 {
    params.input_bore_diameter_mm * 0.6
  } else {
    4.0
  }
  let spider_len = 2.0 * layout.input_apex_offset_mm * 0.6
  comp = comp.add_layer(
    @cad.Cylinder::new(2.0 * spider_r, spider_len),
    name="pitch-spider",
    color=@cad.Rgb::grey(),
    placement=@common.Placement::at(-spider_len / 2.0, 0.0, 0.0, ry=90.0),
  )
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "motor-a-input",
        placement=@common.Placement::translation(
          -layout.input_apex_offset_mm,
          0.0,
          0.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.input_bore_diameter_mm,
        description="left motor A coaxial input bore (+X)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "motor-b-input",
        placement=@common.Placement::translation(
          layout.input_apex_offset_mm,
          0.0,
          0.0,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.input_bore_diameter_mm,
        description="right motor B coaxial input bore (-X)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-shaft",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          layout.output_apex_offset_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.output_bore_diameter_mm,
        description="2-DOF differential output shaft (+Z)",
      ),
    )
  Ok(comp)
}
