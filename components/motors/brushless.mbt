///|
/// BrushlessMotorSpec describes an outrunner brushless-motor envelope.
///
/// The defaults are measured from the owner-authored
/// `components/testdata/golden/external/brushless-motor-360kv.step` model. The frame is
/// +X along the motor axis with `x = 0` at the bell face plane: the shaft runs
/// from `-shaft_rear_extension` to `stator_hub_start + stator_hub_thickness +
/// shaft_front_extension`. The bell face is at `x = 0`, the cylindrical rim
/// starts at `bell_rim_start`, and the fixed stator hub starts at
/// `stator_hub_start`.
///
/// Every dimension can be overridden to match a measured motor. This is a
/// mechanical envelope only: no KV, torque, current, efficiency, or thermal
/// rating is implied.
pub(all) struct BrushlessMotorSpec {
  bell_outer_diameter_mm : Double
  bell_wall_thickness_mm : Double
  bell_face_outer_diameter_mm : Double
  bell_face_thickness_mm : Double
  bell_cone_thickness_mm : Double
  bell_cone_run_mm : Double
  bell_rim_start_mm : Double
  bell_rim_length_mm : Double
  bell_lip_major_radius_mm : Double
  bell_lip_minor_radius_mm : Double
  bell_hub_diameter_mm : Double
  window_count : Int32
  window_inner_diameter_mm : Double
  window_outer_diameter_mm : Double
  window_inner_half_angle_deg : Double
  window_outer_half_angle_deg : Double
  window_corner_radius_mm : Double
  window_phase_deg : Double
  prop_hole_count : Int32
  prop_hole_diameter_mm : Double
  prop_hole_circle_diameter_mm : Double
  stator_hub_diameter_mm : Double
  stator_hub_start_mm : Double
  stator_hub_thickness_mm : Double
  mount_hole_count : Int32
  mount_hole_diameter_mm : Double
  mount_hole_circle_diameter_mm : Double
  shaft_diameter_mm : Double
  shaft_rear_extension_mm : Double
  shaft_front_extension_mm : Double
}

///|
/// brushless_motor_360kv_spec returns the measured defaults from the owner's
/// manual 360KV outrunner model.
pub fn brushless_motor_360kv_spec() -> BrushlessMotorSpec {
  {
    bell_outer_diameter_mm: 50.0,
    bell_wall_thickness_mm: 1.5,
    bell_face_outer_diameter_mm: 45.826,
    bell_face_thickness_mm: 4.0,
    bell_cone_thickness_mm: 3.0,
    bell_cone_run_mm: 2.3,
    bell_rim_start_mm: 3.1665,
    bell_rim_length_mm: 9.1335,
    bell_lip_major_radius_mm: 24.0,
    bell_lip_minor_radius_mm: 1.0,
    bell_hub_diameter_mm: 18.0,
    window_count: 5,
    window_inner_diameter_mm: 18.44,
    window_outer_diameter_mm: 42.19,
    window_inner_half_angle_deg: 15.1,
    window_outer_half_angle_deg: 23.9,
    window_corner_radius_mm: 2.0,
    window_phase_deg: 54.0,
    prop_hole_count: 4,
    prop_hole_diameter_mm: 3.0,
    prop_hole_circle_diameter_mm: 12.0,
    stator_hub_diameter_mm: 25.0,
    stator_hub_start_mm: 18.0,
    stator_hub_thickness_mm: 2.0,
    mount_hole_count: 4,
    mount_hole_diameter_mm: 3.0,
    mount_hole_circle_diameter_mm: 19.0,
    shaft_diameter_mm: 4.0,
    shaft_rear_extension_mm: 2.0,
    shaft_front_extension_mm: 1.0,
  }
}

///|
/// brushless_motor_spec validates a brushless-motor envelope specification.
pub fn brushless_motor_spec(
  spec : BrushlessMotorSpec,
) -> Result[Unit, @common.SpecError] {
  let positive : Array[(String, Double)] = [
    ("brushless bell outer diameter", spec.bell_outer_diameter_mm),
    ("brushless bell wall", spec.bell_wall_thickness_mm),
    ("brushless face outer diameter", spec.bell_face_outer_diameter_mm),
    ("brushless face thickness", spec.bell_face_thickness_mm),
    ("brushless cone thickness", spec.bell_cone_thickness_mm),
    ("brushless cone run", spec.bell_cone_run_mm),
    ("brushless rim length", spec.bell_rim_length_mm),
    ("brushless hub diameter", spec.bell_hub_diameter_mm),
    ("brushless window inner diameter", spec.window_inner_diameter_mm),
    ("brushless window outer diameter", spec.window_outer_diameter_mm),
    ("brushless stator hub diameter", spec.stator_hub_diameter_mm),
    ("brushless stator hub thickness", spec.stator_hub_thickness_mm),
    ("brushless shaft diameter", spec.shaft_diameter_mm),
  ]
  for entry in positive {
    let (name, value) = entry
    match @common.require_positive(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  let non_negative : Array[(String, Double)] = [
    ("brushless rim start", spec.bell_rim_start_mm),
    ("brushless lip major radius", spec.bell_lip_major_radius_mm),
    ("brushless lip minor radius", spec.bell_lip_minor_radius_mm),
    ("brushless stator hub start", spec.stator_hub_start_mm),
    ("brushless shaft rear extension", spec.shaft_rear_extension_mm),
    ("brushless shaft front extension", spec.shaft_front_extension_mm),
    ("brushless window corner radius", spec.window_corner_radius_mm),
  ]
  for entry in non_negative {
    let (name, value) = entry
    match @common.require_non_negative(name, value) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if spec.window_count < 3 {
    return Err(
      @common.InvalidParameter("brushless bell needs at least 3 windows"),
    )
  }
  if spec.prop_hole_count < 1 || spec.mount_hole_count < 1 {
    return Err(
      @common.InvalidParameter(
        "brushless motor needs at least one hole per face",
      ),
    )
  }
  let bell_radius = spec.bell_outer_diameter_mm / 2.0
  let face_radius = spec.bell_face_outer_diameter_mm / 2.0
  let rim_inner_radius = bell_radius - spec.bell_wall_thickness_mm
  if face_radius >= bell_radius {
    return Err(
      @common.InvalidDimension(
        "brushless face must be smaller than the bell rim",
      ),
    )
  }
  if face_radius >= rim_inner_radius {
    return Err(
      @common.InvalidDimension(
        "brushless face must be smaller than the rim inner radius so the lip can bridge it",
      ),
    )
  }
  let hub_radius = spec.bell_hub_diameter_mm / 2.0
  let win_inner = spec.window_inner_diameter_mm / 2.0
  let win_outer = spec.window_outer_diameter_mm / 2.0
  if win_inner <= hub_radius || win_outer >= face_radius {
    return Err(
      @common.InvalidDimension("brushless window does not fit the bell face"),
    )
  }
  if spec.window_outer_half_angle_deg <= spec.window_inner_half_angle_deg ||
    spec.window_outer_half_angle_deg >= 180.0 / spec.window_count.to_double() {
    return Err(
      @common.InvalidParameter(
        "brushless window angles must increase outward and stay within a tooth pitch",
      ),
    )
  }
  if spec.shaft_diameter_mm >= spec.stator_hub_diameter_mm ||
    spec.shaft_diameter_mm >= spec.bell_hub_diameter_mm {
    return Err(
      @common.InvalidDimension("brushless shaft does not fit the hubs"),
    )
  }
  let prop_reach = spec.prop_hole_circle_diameter_mm / 2.0 +
    spec.prop_hole_diameter_mm / 2.0
  if prop_reach >= hub_radius {
    return Err(
      @common.InvalidDimension("brushless prop holes do not fit the bell hub"),
    )
  }
  let mount_reach = spec.mount_hole_circle_diameter_mm / 2.0 +
    spec.mount_hole_diameter_mm / 2.0
  if mount_reach >= spec.stator_hub_diameter_mm / 2.0 {
    return Err(
      @common.InvalidDimension(
        "brushless mount holes do not fit the stator hub",
      ),
    )
  }
  if spec.bell_lip_minor_radius_mm >= spec.bell_lip_major_radius_mm {
    return Err(@common.InvalidDimension("brushless lip radius is invalid"))
  }
  Ok(())
}

///|
/// bl_circle_loop returns a counter-clockwise circle as four minor arcs.
fn bl_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let c = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), c),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), c),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), c),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), c),
  ]
}

///|
/// bl_holes_at_angles returns hole loops on a bolt circle.
fn bl_holes_at_angles(
  count : Int32,
  circle_diameter_mm : Double,
  hole_diameter_mm : Double,
  phase_deg : Double,
) -> Array[Array[@cad.ProfileSegment]] {
  let loops : Array[Array[@cad.ProfileSegment]] = []
  let radius = circle_diameter_mm / 2.0
  let hole_radius = hole_diameter_mm / 2.0
  for i in 0..<count {
    let angle = (phase_deg + 360.0 * i.to_double() / count.to_double()) *
      @math.PI /
      180.0
    loops.push(
      bl_circle_loop(
        radius * @math.cos(angle),
        radius * @math.sin(angle),
        hole_radius,
      ),
    )
  }
  loops
}

///|
/// bl_axis_placement places a Z-extruded profile on the +X motor axis.
fn bl_axis_placement(x_mm : Double) -> @common.Placement {
  @common.Placement::compose(
    @common.Placement::translation(x_mm, 0.0, 0.0),
    @common.Placement::rotation_y(90.0),
  )
}

///|
/// brushless_motor builds a parameterized outrunner brushless-motor envelope.
///
/// The bell is a windowed face plate at `x = 0` plus a cylindrical rim and a
/// rounded lip; the stator hub is a fixed plate at `stator_hub_start`; and the
/// shaft runs along +X. The measured defaults reproduce the owner's manual
/// 360KV model envelope. The 5 window corner radii are recorded as an
/// approximation (the measured model uses 2 mm rounds; this envelope uses the
/// measured arc endpoints with sharp corner transitions).
pub fn brushless_motor(
  spec : BrushlessMotorSpec,
) -> Result[@common.Component, @common.SpecError] {
  match brushless_motor_spec(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let win_inner = spec.window_inner_diameter_mm / 2.0
  let shaft_radius = spec.shaft_diameter_mm / 2.0
  let hub_radius = spec.bell_hub_diameter_mm / 2.0
  let prop_holes = bl_holes_at_angles(
    spec.prop_hole_count,
    spec.prop_hole_circle_diameter_mm,
    spec.prop_hole_diameter_mm,
    0.0,
  )
  let hub_holes : Array[Array[@cad.ProfileSegment]] = [
    bl_circle_loop(0.0, 0.0, shaft_radius),
  ]
  for hole in prop_holes {
    hub_holes.push(hole)
  }
  let hub_plate = @cad.ExtrudedArcProfile::new(
    bl_circle_loop(0.0, 0.0, hub_radius),
    spec.bell_face_thickness_mm,
    holes=hub_holes,
  )
  if !hub_plate.validate() {
    return Err(
      @common.InvalidParameter(
        "brushless bell hub did not form a valid profile",
      ),
    )
  }
  let bell_radius = spec.bell_outer_diameter_mm / 2.0
  let cone_slope = (bell_radius - hub_radius) / spec.bell_cone_run_mm
  let spoke_hub_radius = win_inner
  let spoke_hub_x = (spoke_hub_radius - hub_radius) / cone_slope
  let spoke_rim_radius = spec.bell_lip_major_radius_mm
  let spoke_rim_x = (spoke_rim_radius - hub_radius) / cone_slope
  let cone_span = Double::sqrt(
    (spoke_rim_radius - spoke_hub_radius) *
    (spoke_rim_radius - spoke_hub_radius) +
    (spoke_rim_x - spoke_hub_x) * (spoke_rim_x - spoke_hub_x),
  )
  let pitch_deg = 360.0 / spec.window_count.to_double()
  let inner_half_deg = pitch_deg / 2.0 - spec.window_inner_half_angle_deg
  let outer_half_deg = pitch_deg / 2.0 - spec.window_outer_half_angle_deg
  if inner_half_deg <= 0.0 || outer_half_deg <= 0.0 {
    return Err(
      @common.InvalidParameter(
        "brushless windows leave no material between adjacent windows",
      ),
    )
  }
  let inner_half = inner_half_deg * @math.PI / 180.0
  let outer_half = outer_half_deg * @math.PI / 180.0
  let inner_width = spoke_hub_radius * @math.sin(inner_half)
  let outer_width = spoke_rim_radius * @math.sin(outer_half)
  let spoke_loop : Array[@cad.ProfileSegment] = [
    @cad.SegmentLine((0.0, -inner_width), (cone_span, -outer_width)),
    @cad.SegmentLine((cone_span, -outer_width), (cone_span, outer_width)),
    @cad.SegmentLine((cone_span, outer_width), (0.0, inner_width)),
    @cad.SegmentLine((0.0, inner_width), (0.0, -inner_width)),
  ]
  let spoke = @cad.ExtrudedArcProfile::new(
    spoke_loop,
    spec.bell_cone_thickness_mm,
  )
  if !spoke.validate() {
    return Err(
      @common.InvalidParameter(
        "brushless conical bell spokes did not form a valid profile",
      ),
    )
  }
  let layers : Array[@common.ComponentLayer] = [
    {
      shape: hub_plate.as_shape(),
      name: "bell-hub",
      color: @cad.Rgb::orange(),
      placement: bl_axis_placement(0.0),
    },
  ]
  let gx = (spoke_rim_x - spoke_hub_x) / cone_span
  let gr = (spoke_rim_radius - spoke_hub_radius) / cone_span
  for i in 0..<spec.window_count {
    let phi = (
        spec.window_phase_deg +
        pitch_deg / 2.0 +
        360.0 * i.to_double() / spec.window_count.to_double()
      ) *
      @math.PI /
      180.0
    let radial = (0.0, @math.cos(phi), @math.sin(phi))
    let tangent = (0.0, -@math.sin(phi), @math.cos(phi))
    let generatrix = (gx, gr * radial.1, gr * radial.2)
    let inward = (gr, -gx * radial.1, -gx * radial.2)
    let front_inner = (
      spoke_hub_x,
      spoke_hub_radius * radial.1,
      spoke_hub_radius * radial.2,
    )
    layers.push({
      shape: spoke.as_shape(),
      name: "bell-spoke-\{i + 1}",
      color: @cad.Rgb::orange(),
      placement: {
        rot: @cad.Matrix3x3::{
          m00: generatrix.0,
          m01: tangent.0,
          m02: inward.0,
          m10: generatrix.1,
          m11: tangent.1,
          m12: inward.1,
          m20: generatrix.2,
          m21: tangent.2,
          m22: inward.2,
        },
        trans: front_inner,
      },
    })
  }
  let rim_inner = bell_radius - spec.bell_wall_thickness_mm
  let rim = @cad.RevolvedProfile::tube(
    spec.bell_outer_diameter_mm,
    2.0 * rim_inner,
    spec.bell_rim_length_mm,
  ).as_shape()
  let lip = @cad.RevolvedProfile::new([
    @cad.RevArc(
      (spec.bell_lip_major_radius_mm + spec.bell_lip_minor_radius_mm, 0.0),
      (spec.bell_lip_major_radius_mm, spec.bell_lip_minor_radius_mm),
      (spec.bell_lip_major_radius_mm, 0.0),
    ),
    @cad.RevArc(
      (spec.bell_lip_major_radius_mm, spec.bell_lip_minor_radius_mm),
      (spec.bell_lip_major_radius_mm - spec.bell_lip_minor_radius_mm, 0.0),
      (spec.bell_lip_major_radius_mm, 0.0),
    ),
    @cad.RevArc(
      (spec.bell_lip_major_radius_mm - spec.bell_lip_minor_radius_mm, 0.0),
      (spec.bell_lip_major_radius_mm, -spec.bell_lip_minor_radius_mm),
      (spec.bell_lip_major_radius_mm, 0.0),
    ),
    @cad.RevArc(
      (spec.bell_lip_major_radius_mm, -spec.bell_lip_minor_radius_mm),
      (spec.bell_lip_major_radius_mm + spec.bell_lip_minor_radius_mm, 0.0),
      (spec.bell_lip_major_radius_mm, 0.0),
    ),
  ]).as_shape()
  let mount_holes = bl_holes_at_angles(
    spec.mount_hole_count,
    spec.mount_hole_circle_diameter_mm,
    spec.mount_hole_diameter_mm,
    0.0,
  )
  let hub_holes : Array[Array[@cad.ProfileSegment]] = [
    bl_circle_loop(0.0, 0.0, shaft_radius),
  ]
  for hole in mount_holes {
    hub_holes.push(hole)
  }
  let stator_hub = @cad.ExtrudedArcProfile::new(
    bl_circle_loop(0.0, 0.0, spec.stator_hub_diameter_mm / 2.0),
    spec.stator_hub_thickness_mm,
    holes=hub_holes,
  ).as_shape()
  let total_length = spec.shaft_rear_extension_mm +
    spec.stator_hub_start_mm +
    spec.stator_hub_thickness_mm +
    spec.shaft_front_extension_mm
  let shaft = @cad.RevolvedProfile::cylinder(
    spec.shaft_diameter_mm,
    total_length,
  ).as_shape()
  layers.push({
    shape: rim,
    name: "bell-rim",
    color: @cad.Rgb::orange(),
    placement: bl_axis_placement(spec.bell_rim_start_mm),
  })
  layers.push({
    shape: lip,
    name: "bell-lip",
    color: @cad.Rgb::orange(),
    placement: bl_axis_placement(spec.bell_rim_start_mm),
  })
  layers.push({
    shape: stator_hub,
    name: "stator-hub",
    color: @cad.Rgb::grey(),
    placement: bl_axis_placement(spec.stator_hub_start_mm),
  })
  layers.push({
    shape: shaft,
    name: "shaft",
    color: @cad.Rgb::grey(),
    placement: bl_axis_placement(-spec.shaft_rear_extension_mm),
  })
  let features = @common.FeatureRecord::new(
    modeled=[
      "bell-hub", "bell-cone", "bell-windows", "bell-rim", "bell-lip", "stator-hub",
      "shaft", "prop-holes", "mount-holes",
    ],
    approximated=[
      @common.Approximation::new(
        feature="bell-window-corner-radius",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="measured 2.0 mm rounds are not modelled; the conical spokes have straight edges",
      ),
      @common.Approximation::new(
        feature="bell-cone",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="the conical bell sheet is represented by 5 flat conical-sector spokes",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="stator-windings-magnets-bearings",
        reason="electromechanical internals are not modelled",
      ),
      @common.Omission::new(
        feature="wires-and-connectors",
        reason="no phase wires, bullet connectors, or sensor harness is modelled",
      ),
      @common.Omission::new(
        feature="kv-and-performance",
        reason="no KV, torque, current, efficiency, or thermal rating is implied",
      ),
    ],
  )
  let name = "brushless-motor-\{@cad.fmt_double(spec.bell_outer_diameter_mm, None)}x\{@cad.fmt_double(total_length, None)}"
  let mut motor = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Brushless outrunner bell \{@cad.fmt_double(spec.bell_outer_diameter_mm, None)} x \{@cad.fmt_double(total_length, None)}",
      standard="measured owner-authored 360KV model",
      family="brushless outrunner motor envelope",
      size="\{@cad.fmt_double(spec.bell_outer_diameter_mm, None)}x\{@cad.fmt_double(total_length, None)}",
      length_mm=total_length,
      source="Defaults measured from components/testdata/golden/external/brushless-motor-360kv.step (owner-authored; no third-party license). All dimensions are parameters.",
    ),
    description="Parameterized outrunner brushless-motor envelope with a conical 5-spoke bell, rim and lip, fixed stator hub, prop and mount holes, and a through shaft. No electrical or performance rating is implied.",
    features~,
  ).add_layers(layers)
  let connectors : Array[@common.MateConnector] = [
    @common.MateConnector::new(
      "shaft-rear",
      placement=@common.Placement::translation(
        -spec.shaft_rear_extension_mm,
        0.0,
        0.0,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=spec.shaft_diameter_mm,
      depth_mm=total_length,
      description="negative-X shaft end",
    ),
    @common.MateConnector::new(
      "shaft",
      placement=@common.Placement::translation(
        total_length - spec.shaft_rear_extension_mm,
        0.0,
        0.0,
      ),
      axis=(1.0, 0.0, 0.0),
      kind=@common.MateKind::CylindricalShaft,
      gender=@common.MateGender::Male,
      diameter_mm=spec.shaft_diameter_mm,
      depth_mm=total_length,
      description="positive-X shaft end",
    ),
    @common.MateConnector::new(
      "mount-face",
      placement=@common.Placement::translation(
        spec.stator_hub_start_mm,
        0.0,
        0.0,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.stator_hub_diameter_mm,
      description="fixed stator hub mounting face",
    ),
    @common.MateConnector::new(
      "bell-face",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.bell_face_outer_diameter_mm,
      description="rotating bell face",
    ),
  ]
  for connector in connectors {
    motor = motor.with_connector_unchecked(connector)
  }
  let prop_radius = spec.prop_hole_circle_diameter_mm / 2.0
  for i in 0..<spec.prop_hole_count {
    let angle = 360.0 *
      i.to_double() /
      spec.prop_hole_count.to_double() *
      @math.PI /
      180.0
    motor = motor.with_connector_unchecked(
      @common.MateConnector::new(
        "prop-hole-\{i + 1}",
        placement=@common.Placement::translation(
          0.0,
          prop_radius * @math.cos(angle),
          prop_radius * @math.sin(angle),
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.prop_hole_diameter_mm,
        depth_mm=spec.bell_face_thickness_mm,
        description="propeller mounting hole",
      ),
    )
  }
  let mount_radius = spec.mount_hole_circle_diameter_mm / 2.0
  for i in 0..<spec.mount_hole_count {
    let angle = 360.0 *
      i.to_double() /
      spec.mount_hole_count.to_double() *
      @math.PI /
      180.0
    motor = motor.with_connector_unchecked(
      @common.MateConnector::new(
        "mount-hole-\{i + 1}",
        placement=@common.Placement::translation(
          spec.stator_hub_start_mm,
          mount_radius * @math.cos(angle),
          mount_radius * @math.sin(angle),
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.mount_hole_diameter_mm,
        depth_mm=spec.stator_hub_thickness_mm,
        description="stator mounting hole",
      ),
    )
  }
  Ok(motor)
}

///|
/// brushless_motor_360kv builds the measured owner-authored 360KV envelope.
pub fn brushless_motor_360kv() -> Result[@common.Component, @common.SpecError] {
  brushless_motor(brushless_motor_360kv_spec())
}
