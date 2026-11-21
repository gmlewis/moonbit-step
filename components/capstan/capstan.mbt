///|
/// Parametric capstan / cable drive (`gmlewis/step/components/capstan`).
///
/// Models a zero-backlash, ultra-high-efficiency (~95%), backdrivable cable
/// transmission widely used in robot arms, wrists, hands, and legged joints:
/// - **Capstan input drum (`capstan-drum`)** at `(0, 0, 0)` along `+Z`.
/// - **Driven drum or arc sector (`driven-drum`)** at `(center_distance, 0, 0)`.
/// - **Tangent tensioned cable strands (`cable-top`, `cable-bottom`)** spanning
///   the exact outer tangent points of both pitch circles.

///|
const CAP_PI : Double = 3.141592653589793

///|
/// Input parameters for a parametric capstan / cable drive.
pub(all) struct CapstanParams {
  /// Small input capstan drum radius in mm.
  capstan_radius_mm : Double
  /// Large driven drum/sector radius in mm.
  driven_radius_mm : Double
  /// Cable / wire-rope diameter in mm.
  cable_diameter_mm : Double
  /// Axial width of both drums in mm.
  drum_width_mm : Double
  /// Output angular travel in degrees (`30 .. 360`; `< 360` models a compact arc sector).
  travel_deg : Double
  /// Radial gap between the two drum outer circumferences in mm.
  clearance_mm : Double
  /// Input shaft bore radius in mm.
  capstan_bore_radius_mm : Double
  /// Output shaft bore radius in mm.
  driven_bore_radius_mm : Double
  /// If `true`, figure-8 crossed cable (opposing rotation, negative ratio);
  /// if `false`, open parallel tangent cable (same rotation direction).
  crossed : Bool
}

///|
/// Builds and validates `CapstanParams`.
pub fn CapstanParams::new(
  capstan_radius_mm~ : Double = 8.0,
  driven_radius_mm~ : Double = 48.0,
  cable_diameter_mm~ : Double = 1.5,
  drum_width_mm~ : Double = 16.0,
  travel_deg~ : Double = 180.0,
  clearance_mm~ : Double = 4.0,
  capstan_bore_radius_mm~ : Double = 4.0,
  driven_bore_radius_mm~ : Double = 6.35,
  crossed~ : Bool = false,
) -> Result[CapstanParams, @common.SpecError] {
  if capstan_radius_mm <= 0.0 || driven_radius_mm <= 0.0 {
    return Err(@common.InvalidParameter("drum radii must be positive"))
  }
  if cable_diameter_mm <= 0.0 || drum_width_mm <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "cable_diameter_mm and drum_width_mm must be > 0",
      ),
    )
  }
  if travel_deg < 30.0 || travel_deg > 360.0 {
    return Err(@common.InvalidParameter("travel_deg must be in [30, 360]"))
  }
  if clearance_mm < 0.0 {
    return Err(@common.InvalidParameter("clearance_mm must be >= 0"))
  }
  if capstan_bore_radius_mm <= 0.0 ||
    capstan_bore_radius_mm >= capstan_radius_mm - 1.5 {
    return Err(
      @common.InvalidParameter(
        "capstan_bore_radius_mm does not fit inside capstan_radius_mm",
      ),
    )
  }
  if driven_bore_radius_mm <= 0.0 ||
    driven_bore_radius_mm >= driven_radius_mm - 2.0 {
    return Err(
      @common.InvalidParameter(
        "driven_bore_radius_mm does not fit inside driven_radius_mm",
      ),
    )
  }
  Ok({
    capstan_radius_mm,
    driven_radius_mm,
    cable_diameter_mm,
    drum_width_mm,
    travel_deg,
    clearance_mm,
    capstan_bore_radius_mm,
    driven_bore_radius_mm,
    crossed,
  })
}

///|
/// Derived geometry and kinematics for a capstan / cable drive.
pub(all) struct CapstanLayout {
  params : CapstanParams
  /// Effective cable pitch radius on the capstan (`r1 + d_c/2`).
  capstan_pitch_radius_mm : Double
  /// Effective cable pitch radius on the driven drum (`r2 + d_c/2`).
  driven_pitch_radius_mm : Double
  /// Exact reduction magnitude (`driven_pitch / capstan_pitch`).
  reduction_ratio : Double
  /// Signed reduction ratio (`-reduction_ratio` if crossed, `+reduction_ratio` if open).
  signed_reduction : Double
  /// Center-to-center distance between capstan and driven axes in mm.
  center_distance_mm : Double
  /// Minimum recommended cable wraps around the capstan for `travel_deg`.
  required_wraps : Int32
  /// Estimated mechanical efficiency (~0.95).
  efficiency : Double
}

///|
/// Computes the derived layout of a capstan / cable drive.
pub fn capstan_layout(params : CapstanParams) -> CapstanLayout {
  let r1 = params.capstan_radius_mm + params.cable_diameter_mm / 2.0
  let r2 = params.driven_radius_mm + params.cable_diameter_mm / 2.0
  let reduction_ratio = r2 / r1
  let signed_reduction = if params.crossed {
    -reduction_ratio
  } else {
    reduction_ratio
  }
  let center_distance_mm = params.capstan_radius_mm +
    params.driven_radius_mm +
    params.cable_diameter_mm +
    params.clearance_mm
  let active_turns = params.travel_deg / 360.0 * reduction_ratio
  let required_wraps = active_turns.ceil().to_int() + 2
  {
    params,
    capstan_pitch_radius_mm: r1,
    driven_pitch_radius_mm: r2,
    reduction_ratio,
    signed_reduction,
    center_distance_mm,
    required_wraps,
    efficiency: 0.95,
  }
}

///|
/// Builds a parametric capstan / cable drive as a `@common.Component` along `+Z`.
pub fn capstan_drive(
  params : CapstanParams,
  y_up~ : Bool = false,
) -> Result[@common.Component, @common.SpecError] {
  let layout = capstan_layout(params)
  let name = "capstan-r\{@cad.fmt_double(params.capstan_radius_mm, None)}-R\{@cad.fmt_double(params.driven_radius_mm, None)}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "capstan-input-drum", "driven-output-drum", "tensioned-cable-strands",
    ],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="helical-cable-grooves",
        reason="modeled as smooth cylindrical pitch drums with tangent cable strands",
      ),
    ],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Capstan cable drive \{@cad.fmt_double(layout.reduction_ratio, None)}:1 (r1=\{@cad.fmt_double(params.capstan_radius_mm, None)} mm, r2=\{@cad.fmt_double(params.driven_radius_mm, None)} mm, travel=\{@cad.fmt_double(params.travel_deg, None)} deg)",
      family="capstan cable drive",
      size="r\{@cad.fmt_double(params.capstan_radius_mm, None)}-R\{@cad.fmt_double(params.driven_radius_mm, None)}",
      length_mm=params.drum_width_mm,
      source="Parametric zero-backlash capstan cable drive.",
    ),
    description="Zero-backlash, backdrivable capstan cable drive with input drum, driven drum, and tangent cable strands.",
    features~,
  )
  // 1. Input capstan drum at (0, 0, 0).
  let cap_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * params.capstan_radius_mm),
    params.drum_width_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.capstan_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    cap_shape,
    name="capstan-drum",
    color=@cad.Rgb::orange(),
    placement=@common.Placement::identity(),
  )
  // 2. Driven output drum at (center_distance, 0, 0).
  let driven_shape = @cad.ExtrudedArcProfile::new(
    @gears.arc_circle_segments(2.0 * params.driven_radius_mm),
    params.drum_width_mm,
    holes=[@gears.arc_circle_segments(2.0 * params.driven_bore_radius_mm)],
  ).as_shape()
  comp = comp.add_layer(
    driven_shape,
    name="driven-drum",
    color=@cad.Rgb::blue(),
    placement=@common.Placement::translation(
      layout.center_distance_mm,
      0.0,
      0.0,
    ),
  )
  // 3. Tangent cable strands spanning from capstan to driven drum at mid-plane.
  let c = layout.center_distance_mm
  let r1 = layout.capstan_pitch_radius_mm
  let r2 = layout.driven_pitch_radius_mm
  let z_mid = params.drum_width_mm / 2.0
  let (sin_a, strand_len) = if params.crossed {
    let s = (r1 + r2) / c
    let s_clamped = if s > 0.99 { 0.99 } else { s }
    (s_clamped, (c * c - (r1 + r2) * (r1 + r2)).abs().sqrt())
  } else {
    let s = (r2 - r1) / c
    (s, (c * c - (r2 - r1) * (r2 - r1)).abs().sqrt())
  }
  let alpha = @math.asin(sin_a)
  let alpha_deg = alpha * 180.0 / CAP_PI
  let cable_shape = @cad.Cylinder::new(params.cable_diameter_mm, strand_len)
  if params.crossed {
    // Top-left to bottom-right and bottom-left to top-right.
    let x1 = r1 * @math.sin(alpha)
    let y1 = r1 * @math.cos(alpha)
    comp = comp
      .add_layer(
        cable_shape,
        name="cable-strand-1",
        color=@cad.Rgb::new(0.75, 0.78, 0.82),
        placement=@common.Placement::at(x1, y1, z_mid, ry=90.0, rz=-alpha_deg),
      )
      .add_layer(
        cable_shape,
        name="cable-strand-2",
        color=@cad.Rgb::new(0.75, 0.78, 0.82),
        placement=@common.Placement::at(x1, -y1, z_mid, ry=90.0, rz=alpha_deg),
      )
  } else {
    let x1 = -r1 * @math.sin(alpha)
    let y1 = r1 * @math.cos(alpha)
    comp = comp
      .add_layer(
        cable_shape,
        name="cable-strand-1",
        color=@cad.Rgb::new(0.75, 0.78, 0.82),
        placement=@common.Placement::at(x1, y1, z_mid, ry=90.0, rz=alpha_deg),
      )
      .add_layer(
        cable_shape,
        name="cable-strand-2",
        color=@cad.Rgb::new(0.75, 0.78, 0.82),
        placement=@common.Placement::at(x1, -y1, z_mid, ry=90.0, rz=-alpha_deg),
      )
  }
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "input-bore",
        placement=@common.Placement::identity(),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.capstan_bore_radius_mm,
        depth_mm=params.drum_width_mm,
        description="capstan input shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-bore",
        placement=@common.Placement::translation(
          layout.center_distance_mm,
          0.0,
          0.0,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=2.0 * params.driven_bore_radius_mm,
        depth_mm=params.drum_width_mm,
        description="driven output shaft bore",
      ),
    )
  if y_up {
    comp = comp.rotate_x(-90.0)
  }
  Ok(comp)
}
