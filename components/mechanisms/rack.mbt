///|
/// RackPinionLayout records the rack-to-pinion interface for a standard
/// full-depth rack and a spur pinion.
pub(all) struct RackPinionLayout {
  module_mm : Double
  rack_teeth : Int32
  pinion_teeth : Int32
  pitch_line_mm : Double
  center_distance_mm : Double
  rack_travel_per_revolution_mm : Double
}

///|
/// rack_pinion_layout computes the rack-and-pinion interface.
///
/// The rack pitch line is at `pitch_line_mm` above the rack base (the rack's
/// dedendum). The pinion pitch radius is `module * pinion_teeth / 2`, and one
/// pinion revolution advances the rack by `pi * module * pinion_teeth`. The rack
/// length is `rack_teeth * pi * module`.
pub fn rack_pinion_layout(
  module_mm : Double,
  rack_teeth : Int32,
  pinion_teeth : Int32,
) -> Result[RackPinionLayout, @common.SpecError] {
  match mechanism_checks([("rack module", module_mm)]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if rack_teeth < 2 {
    return Err(@common.InvalidParameter("rack needs at least two teeth"))
  }
  if pinion_teeth < 6 {
    return Err(@common.InvalidParameter("pinion needs at least six teeth"))
  }
  let pitch = @math.PI * module_mm
  Ok({
    module_mm,
    rack_teeth,
    pinion_teeth,
    pitch_line_mm: 1.25 * module_mm,
    center_distance_mm: module_mm * pinion_teeth.to_double() / 2.0,
    rack_travel_per_revolution_mm: pitch * pinion_teeth.to_double(),
  })
}

///|
/// rack_gear builds a standard full-depth rack as a real prismatic solid.
///
/// Frame: the rack runs along +X from `x = 0` to
/// `x = teeth * pi * module`, its height is along +Y, and its thickness is along
/// +Z from `z = 0` to `thickness`. The base is `base_thickness` deep; the pitch
/// line is at `base_thickness + 1.25 * module` and tooth tips at
/// `base_thickness + 2.25 * module`. The flanks are exact straight-sided basic
/// rack flanks at `pressure_angle_deg`; tips and roots are sharp line corners.
///
/// Two analytic mounting holes pass through the base along Z. This is a generic
/// rack tooth form, not a vendor part; no strength rating is implied.
pub fn rack_gear(
  module_mm : Double,
  teeth : Int32,
  base_thickness_mm : Double,
  thickness_mm : Double,
  pressure_angle_deg~ : Double = 20.0,
  mount_hole_diameter_mm~ : Double = 4.5,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match
    mechanism_checks([
      ("rack module", module_mm),
      ("rack base thickness", base_thickness_mm),
      ("rack thickness", thickness_mm),
      ("rack mount hole diameter", mount_hole_diameter_mm),
    ]) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth < 2 {
    return Err(@common.InvalidParameter("rack needs at least two teeth"))
  }
  if pressure_angle_deg <= 0.0 || pressure_angle_deg >= 45.0 {
    return Err(
      @common.InvalidParameter(
        "rack pressure angle must be between 0 and 45 degrees",
      ),
    )
  }
  if mount_hole_diameter_mm >= base_thickness_mm {
    return Err(
      @common.InvalidDimension(
        "rack mounting hole does not fit the base thickness",
      ),
    )
  }
  let pitch = @math.PI * module_mm
  let length = pitch * teeth.to_double()
  let alpha = pressure_angle_deg * @math.PI / 180.0
  let tan_alpha = @math.tan(alpha)
  let root_half = pitch / 4.0 + 1.25 * module_mm * tan_alpha
  let tip_half = pitch / 4.0 - module_mm * tan_alpha
  if tip_half <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "rack tooth tip width is not positive at this pressure angle and module",
      ),
    )
  }
  if 2.0 * root_half >= pitch {
    return Err(
      @common.InvalidParameter("rack tooth root width leaves no tooth space"),
    )
  }
  let root_y = base_thickness_mm
  let pitch_y = root_y + 1.25 * module_mm
  let tip_y = pitch_y + module_mm
  let points : Array[(Double, Double)] = [
    (0.0, 0.0),
    (length, 0.0),
    (length, root_y),
  ]
  for i in 0..<teeth {
    let index = teeth - 1 - i
    let center = (index.to_double() + 0.5) * pitch
    points.push((center + root_half, root_y))
    points.push((center + tip_half, tip_y))
    points.push((center - tip_half, tip_y))
    points.push((center - root_half, root_y))
  }
  points.push((0.0, root_y))
  if @cad.polygon_area_2d(points) <= 0.0 {
    return Err(
      @common.InvalidParameter("rack profile is not counter-clockwise"),
    )
  }
  let hole_radius = mount_hole_diameter_mm / 2.0
  let hole_x = base_thickness_mm * 1.5
  let hole_y = base_thickness_mm / 2.0
  if hole_x + hole_radius >= length / 2.0 {
    return Err(
      @common.InvalidDimension("rack is too short for the mounting holes"),
    )
  }
  let holes = [
    circle_loop(hole_x, hole_y, hole_radius),
    circle_loop(length - hole_x, hole_y, hole_radius),
  ]
  let outline : Array[@cad.ProfileSegment] = []
  let count = points.length()
  for i in 0..<count {
    let start = points[i]
    let end = points[(i + 1) % count]
    outline.push(@cad.SegmentLine(start, end))
  }
  let body = @cad.ExtrudedArcProfile::new(outline, thickness_mm, holes~).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["rack-body", "straight-flank-teeth", "mounting-holes"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="tooth-tip-and-root-fillets",
        reason="tips and roots are sharp; no trochoid or fillet is modelled",
      ),
      @common.Omission::new(
        feature="profile-shift-and-helix",
        reason="the rack is a straight basic rack; no shift or helix is modelled",
      ),
    ],
  )
  let name = "rack-m\{@cad.fmt_double(module_mm, None)}-z\{teeth}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Rack module \{@cad.fmt_double(module_mm, None)}, \{teeth} teeth",
        family="rack (basic tooth form)",
        size="m\{@cad.fmt_double(module_mm, None)}-z\{teeth}",
        source="Parametric straight-flank basic rack with exact line flanks and sharp tips and roots.",
      ),
      description="Straight-sided basic rack with real tooth spaces and two through mounting holes. Tips and roots are sharp.",
      features~,
    )
    .add_layer(body, name="rack", color~)
    .with_connector_unchecked(
      @common.MateConnector::new(
        "pitch-plane",
        placement=@common.Placement::translation(
          length / 2.0,
          pitch_y,
          thickness_mm / 2.0,
        ),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=pitch,
        description="rack pitch plane, outward normal +Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "base-face",
        placement=@common.Placement::translation(
          length / 2.0,
          0.0,
          thickness_mm / 2.0,
        ),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=pitch,
        description="rack mounting face, outward normal -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(
          0.0,
          pitch_y,
          thickness_mm / 2.0,
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tip_y,
        description="negative-X rack end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(
          length,
          pitch_y,
          thickness_mm / 2.0,
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::Datum,
        diameter_mm=tip_y,
        description="positive-X rack end datum",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-1",
        placement=@common.Placement::translation(hole_x, hole_y, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=mount_hole_diameter_mm,
        depth_mm=thickness_mm,
        description="negative-X rack mounting hole",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-2",
        placement=@common.Placement::translation(length - hole_x, hole_y, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=mount_hole_diameter_mm,
        depth_mm=thickness_mm,
        description="positive-X rack mounting hole",
      ),
    ),
  )
}
