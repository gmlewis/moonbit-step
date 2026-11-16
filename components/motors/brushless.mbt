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
/// The large endbell is the **rotor**; the circular stator hub on the opposite
/// side is the fixed **stator** and is the only part that may be bolted to an
/// enclosure. See `brushless_motor` for the full connector roles.
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
/// bl_polar returns a point at a radius and angle in degrees.
fn bl_polar(radius : Double, angle_deg : Double) -> (Double, Double) {
  let angle = angle_deg * @math.PI / 180.0
  (radius * @math.cos(angle), radius * @math.sin(angle))
}

///|
/// bl_side_tangent returns the two tangent points of a straight side between
/// equal-radius corner fillets. `sign` mirrors the normal to the correct side
/// of the window.
fn bl_side_tangent(
  c1 : (Double, Double),
  c2 : (Double, Double),
  radius : Double,
  sign : Double,
) -> ((Double, Double), (Double, Double)) {
  let dx = c2.0 - c1.0
  let dy = c2.1 - c1.1
  let length = Double::sqrt(dx * dx + dy * dy)
  let nx = sign * (-dy / length)
  let ny = sign * (dx / length)
  (
    (c1.0 + radius * nx, c1.1 + radius * ny),
    (c2.0 + radius * nx, c2.1 + radius * ny),
  )
}

///|
/// bl_window_loop returns the rounded annular-sector window cutter profile.
///
/// The measured window has a circular inner edge, a circular outer edge, two
/// straight sides, and a 2 mm round at each corner. The fillets are tangent to
/// both the arc and the side, so the loop is exact rather than chorded.
fn bl_window_loop(
  center_deg : Double,
  inner_radius : Double,
  outer_radius : Double,
  inner_half_deg : Double,
  outer_half_deg : Double,
  fillet_radius : Double,
) -> Array[@cad.ProfileSegment] {
  let inner_left_angle = center_deg - inner_half_deg
  let inner_right_angle = center_deg + inner_half_deg
  let outer_left_angle = center_deg - outer_half_deg
  let outer_right_angle = center_deg + outer_half_deg
  let inner_left = bl_polar(inner_radius, inner_left_angle)
  let inner_right = bl_polar(inner_radius, inner_right_angle)
  let outer_left = bl_polar(outer_radius, outer_left_angle)
  let outer_right = bl_polar(outer_radius, outer_right_angle)
  let inner_center_left = bl_polar(
    inner_radius + fillet_radius,
    inner_left_angle,
  )
  let inner_center_right = bl_polar(
    inner_radius + fillet_radius,
    inner_right_angle,
  )
  let outer_center_left = bl_polar(
    outer_radius - fillet_radius,
    outer_left_angle,
  )
  let outer_center_right = bl_polar(
    outer_radius - fillet_radius,
    outer_right_angle,
  )
  let (inner_side_left, outer_side_left) = bl_side_tangent(
    inner_center_left, outer_center_left, fillet_radius, -1.0,
  )
  let (inner_side_right, outer_side_right) = bl_side_tangent(
    inner_center_right, outer_center_right, fillet_radius, 1.0,
  )
  let origin = (0.0, 0.0)
  // Build the loop counter-clockwise, then reverse it because these points run
  // clockwise around the window when read in this order.
  let clockwise : Array[@cad.ProfileSegment] = [
    @cad.SegmentArc(inner_left, inner_right, origin),
    @cad.SegmentArc(inner_right, inner_side_right, inner_center_right),
    @cad.SegmentLine(inner_side_right, outer_side_right),
    @cad.SegmentArc(outer_side_right, outer_right, outer_center_right),
    @cad.SegmentArc(outer_right, outer_left, origin),
    @cad.SegmentArc(outer_left, outer_side_left, outer_center_left),
    @cad.SegmentLine(outer_side_left, inner_side_left),
    @cad.SegmentArc(inner_side_left, inner_left, inner_center_left),
  ]
  let reversed : Array[@cad.ProfileSegment] = []
  for i in 0..<clockwise.length() {
    match clockwise[clockwise.length() - 1 - i] {
      @cad.SegmentArc(a, b, c) => reversed.push(@cad.SegmentArc(b, a, c))
      @cad.SegmentLine(a, b) => reversed.push(@cad.SegmentLine(b, a))
    }
  }
  reversed
}

///|
/// bl_loop_center returns the center of a circular hole loop.
fn bl_loop_center(segments : Array[@cad.ProfileSegment]) -> (Double, Double) {
  match segments[0] {
    @cad.SegmentArc(_, _, center) => center
    @cad.SegmentLine(a, _) => a
  }
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
/// brushless_motor builds a parameterized outrunner brushless-motor envelope.
///
/// The bell is a windowed face plate at `x = 0` plus a cylindrical rim and a
/// rounded lip; the stator hub is a fixed plate at `stator_hub_start`; and the
/// shaft runs along +X. The measured defaults reproduce the owner's manual
/// 360KV model envelope. The 5 window corner radii are recorded as an
/// approximation (the measured model uses 2 mm rounds; this envelope uses the
/// measured arc endpoints with sharp corner transitions).
///
/// **Rotor / stator role convention (important when building an assembly):**
///
/// - The large windowed **bell is the rotor**. It spins. Attach gears,
///   pulleys, propellers, or other moving parts only through
///   `rotor-output-face`, `rotor-output-hole-*`, or the rotating
///   `rotor-shaft-*` ends.
/// - The circular **stator hub on the opposite side is the stator**. It must
///   be bolted to the motor enclosure, frame, or gearbox housing through
///   `stator-mount-face` and `stator-mount-hole-*`. Nothing that must rotate
///   may be attached to the stator face.
pub fn brushless_motor(
  spec : BrushlessMotorSpec,
) -> Result[@common.Component, @common.SpecError] {
  match brushless_motor_spec(spec) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let hub_radius = spec.bell_hub_diameter_mm / 2.0
  let bell_radius = spec.bell_outer_diameter_mm / 2.0
  let rim_inner = bell_radius - spec.bell_wall_thickness_mm
  let bore_radius = spec.shaft_diameter_mm / 2.0
  let win_inner = spec.window_inner_diameter_mm / 2.0
  let cone_slope = (bell_radius - hub_radius) / spec.bell_cone_run_mm
  let normal_length = Double::sqrt(1.0 + cone_slope * cone_slope)
  let front_x = fn(r : Double) { (r - hub_radius) / cone_slope }
  // The rear cone is a parallel offset by the sheet thickness: at the same
  // radius it lies `t * sqrt(1 + slope^2) / slope` further along +X.
  let rear_x = fn(r : Double) {
    front_x(r) + spec.bell_cone_thickness_mm * normal_length / cone_slope
  }
  let rim_inner_start = rear_x(rim_inner)
  let window_inner_start = rear_x(win_inner)
  // Front cone tangent to the rounded lip torus.
  let lip_center = (spec.bell_lip_major_radius_mm, spec.bell_rim_start_mm)
  let hub_point = (hub_radius, 0.0)
  let dx = lip_center.0 - hub_point.0
  let dz = lip_center.1 - hub_point.1
  let center_distance = Double::sqrt(dx * dx + dz * dz)
  let minor = spec.bell_lip_minor_radius_mm
  let tangent_scale = (center_distance * center_distance - minor * minor) /
    (center_distance * center_distance)
  let tangent_bulge = minor *
    Double::sqrt(center_distance * center_distance - minor * minor) /
    (center_distance * center_distance)
  let tangent_point = (
    hub_point.0 + tangent_scale * dx + tangent_bulge * dz,
    hub_point.1 + tangent_scale * dz - tangent_bulge * dx,
  )
  let lip_outer = (
    spec.bell_lip_major_radius_mm + minor,
    spec.bell_rim_start_mm,
  )
  let bell_profile = @cad.RevolvedProfile::new([
    @cad.RevLine((bore_radius, 0.0), (hub_radius, 0.0)),
    @cad.RevLine((hub_radius, 0.0), tangent_point),
    @cad.RevArc(tangent_point, lip_outer, lip_center),
    @cad.RevLine(
      lip_outer,
      (bell_radius, spec.bell_rim_start_mm + spec.bell_rim_length_mm),
    ),
    @cad.RevLine(
      (bell_radius, spec.bell_rim_start_mm + spec.bell_rim_length_mm),
      (rim_inner, spec.bell_rim_start_mm + spec.bell_rim_length_mm),
    ),
    @cad.RevLine(
      (rim_inner, spec.bell_rim_start_mm + spec.bell_rim_length_mm),
      (rim_inner, rim_inner_start),
    ),
    @cad.RevLine((rim_inner, rim_inner_start), (win_inner, window_inner_start)),
    @cad.RevLine(
      (win_inner, window_inner_start),
      (hub_radius, window_inner_start),
    ),
    @cad.RevLine(
      (hub_radius, window_inner_start),
      (hub_radius, spec.bell_face_thickness_mm),
    ),
    @cad.RevLine(
      (hub_radius, spec.bell_face_thickness_mm),
      (bore_radius, spec.bell_face_thickness_mm),
    ),
    @cad.RevLine((bore_radius, spec.bell_face_thickness_mm), (bore_radius, 0.0)),
  ])
  match bell_profile.validate() {
    Err(e) =>
      return Err(
        @common.InvalidParameter("brushless bell profile: \{e.message()}"),
      )
    Ok(_) => ()
  }
  let bell_body = bell_profile.as_shape().with_name("bell-body").rotate_y(90.0)
  let window_cutters : Array[@cad.SceneNode] = []
  for i in 0..<spec.window_count {
    // The profile is built in XY and then rotated +90 degrees about Y onto the
    // +X motor axis, which maps profile angle θ to world YZ angle θ - 90.
    // Adding 90 keeps `window_phase_deg` in the model's measured YZ frame.
    let center = spec.window_phase_deg +
      90.0 +
      360.0 * i.to_double() / spec.window_count.to_double()
    let window_profile = bl_window_loop(
      center,
      win_inner,
      spec.window_outer_diameter_mm / 2.0,
      spec.window_inner_half_angle_deg,
      spec.window_outer_half_angle_deg,
      spec.window_corner_radius_mm,
    )
    let cutter = @cad.ExtrudedArcProfile::new(
      window_profile,
      spec.bell_rim_start_mm + 3.0,
    )
    if !cutter.validate() {
      return Err(
        @common.InvalidParameter(
          "brushless window cutter did not form a valid profile",
        ),
      )
    }
    window_cutters.push(
      cutter
      .as_shape()
      .with_name("window-cutter-\{i + 1}")
      .rotate_y(90.0)
      .translate(x=-1.0),
    )
  }
  for
    hole in bl_holes_at_angles(
      spec.prop_hole_count,
      spec.prop_hole_circle_diameter_mm,
      spec.prop_hole_diameter_mm,
      0.0,
    ) {
    let (hx, hy) = bl_loop_center(hole)
    window_cutters.push(
      @cad.RevolvedProfile::cylinder(
        spec.prop_hole_diameter_mm,
        spec.bell_face_thickness_mm + 2.0,
      )
      .as_shape()
      .with_name("prop-hole-cutter")
      .rotate_y(90.0)
      .translate(x=-1.0, y=hx, z=hy),
    )
  }
  let bell = @cad.difference(bell_body, window_cutters, name="bell")
  let stator_base = @cad.RevolvedProfile::cylinder(
      spec.stator_hub_diameter_mm,
      spec.stator_hub_thickness_mm,
    )
    .as_shape()
    .with_name("stator-base")
    .rotate_y(90.0)
    .translate(x=spec.stator_hub_start_mm)
  let stator_cutters : Array[@cad.SceneNode] = [
    @cad.RevolvedProfile::cylinder(
      spec.shaft_diameter_mm,
      spec.stator_hub_thickness_mm + 2.0,
    )
    .as_shape()
    .with_name("stator-bore-cutter")
    .rotate_y(90.0)
    .translate(x=spec.stator_hub_start_mm - 1.0),
  ]
  for
    hole in bl_holes_at_angles(
      spec.mount_hole_count,
      spec.mount_hole_circle_diameter_mm,
      spec.mount_hole_diameter_mm,
      0.0,
    ) {
    let (hx, hy) = bl_loop_center(hole)
    stator_cutters.push(
      @cad.RevolvedProfile::cylinder(
        spec.mount_hole_diameter_mm,
        spec.stator_hub_thickness_mm + 2.0,
      )
      .as_shape()
      .with_name("mount-hole-cutter")
      .rotate_y(90.0)
      .translate(x=spec.stator_hub_start_mm - 1.0, y=hx, z=hy),
    )
  }
  let stator = @cad.difference(stator_base, stator_cutters, name="stator-hub")
  let total_length = spec.shaft_rear_extension_mm +
    spec.stator_hub_start_mm +
    spec.stator_hub_thickness_mm +
    spec.shaft_front_extension_mm
  let shaft = @cad.RevolvedProfile::cylinder(
    spec.shaft_diameter_mm,
    total_length,
  ).as_shape()
  let shaft_placement = @common.Placement::compose(
    @common.Placement::translation(-spec.shaft_rear_extension_mm, 0.0, 0.0),
    @common.Placement::rotation_y(90.0),
  )
  let layers : Array[@common.ComponentLayer] = [
    {
      shape: bell.shape_intent(),
      name: "bell",
      color: @cad.Rgb::orange(),
      placement: @common.Placement::identity(),
    },
    {
      shape: stator.shape_intent(),
      name: "stator-hub",
      color: @cad.Rgb::grey(),
      placement: @common.Placement::identity(),
    },
    {
      shape: shaft,
      name: "shaft",
      color: @cad.Rgb::grey(),
      placement: shaft_placement,
    },
  ]
  let features = @common.FeatureRecord::new(
    modeled=[
      "bell-hub", "bell-cone", "bell-windows", "rounded-window-corners", "bell-rim",
      "bell-lip", "stator-hub", "shaft", "prop-holes", "mount-holes",
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
      "rotor-shaft-bell-side",
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
      description="ROTATING rotor shaft end on the endbell side; drives gears, pulleys, or couplings; never clamp it to the enclosure",
    ),
    @common.MateConnector::new(
      "rotor-shaft-mount-side",
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
      description="ROTATING rotor shaft end on the stator mount side; drives gears, pulleys, or couplings; never clamp it to the enclosure",
    ),
    @common.MateConnector::new(
      "stator-mount-face",
      placement=@common.Placement::translation(
        spec.stator_hub_start_mm + spec.stator_hub_thickness_mm,
        0.0,
        0.0,
      ),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.stator_hub_diameter_mm,
      description="FIXED stator mount face; bolt this face to the motor enclosure or frame; it never rotates",
    ),
    @common.MateConnector::new(
      "rotor-output-face",
      placement=@common.Placement::translation(0.0, 0.0, 0.0),
      axis=(-1.0, 0.0, 0.0),
      kind=@common.MateKind::PlaneFace,
      diameter_mm=spec.bell_face_outer_diameter_mm,
      description="ROTATING rotor endbell output face; attach a propeller, gear, or pulley here, never the enclosure",
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
        "rotor-output-hole-\{i + 1}",
        placement=@common.Placement::translation(
          0.0,
          prop_radius * @math.cos(angle),
          prop_radius * @math.sin(angle),
        ),
        axis=(1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.prop_hole_diameter_mm,
        depth_mm=spec.bell_face_thickness_mm,
        description="screw hole on the ROTATING rotor output face; attach a gear, pulley, or propeller here",
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
        "stator-mount-hole-\{i + 1}",
        placement=@common.Placement::translation(
          spec.stator_hub_start_mm + spec.stator_hub_thickness_mm,
          mount_radius * @math.cos(angle),
          mount_radius * @math.sin(angle),
        ),
        axis=(-1.0, 0.0, 0.0),
        kind=@common.MateKind::CylindricalBore,
        diameter_mm=spec.mount_hole_diameter_mm,
        depth_mm=spec.stator_hub_thickness_mm,
        description="clearance hole in the FIXED stator mount face; bolt it to the enclosure",
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
