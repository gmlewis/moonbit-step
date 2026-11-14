///|
/// components/examples/brushless_motor
///
/// Generate a parameterized outrunner brushless-motor envelope. The defaults
/// are measured from the owner-authored 360KV model in
/// `components/testdata/golden/external/brushless-motor-360kv.step`; override any value
/// to match a motor you measured.
///
/// ```bash
/// moon run components/examples/brushless_motor -- -o /tmp/motor.step
/// moon run components/examples/brushless_motor -- \
///   --bellDiameter 42 --faceDiameter 38 --hubDiameter 15 \
///   --windowInner 16 --windowOuter 35 --lipRadius 20 \
///   --statorDiameter 24 --shaftDiameter 3 --propHoleCircle 10 \
///   -o /tmp/motor42.step
/// ```
async fn main {
  let base = @motors.brushless_motor_360kv_spec()
  let spec = {
    "bellDiameter": @cli.opt_double(
      base.bell_outer_diameter_mm,
      help="Bell outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bellWall": @cli.opt_double(
      base.bell_wall_thickness_mm,
      help="Bell cylindrical wall thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "faceDiameter": @cli.opt_double(
      base.bell_face_outer_diameter_mm,
      help="Bell face plate outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "faceThickness": @cli.opt_double(
      base.bell_face_thickness_mm,
      help="Bell hub plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coneThickness": @cli.opt_double(
      base.bell_cone_thickness_mm,
      help="Conical bell sheet thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coneRun": @cli.opt_double(
      base.bell_cone_run_mm,
      help="Axial run from the hub face to the full bell radius in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "rimStart": @cli.opt_double(
      base.bell_rim_start_mm,
      help="Axial start of the cylindrical rim in mm",
      min=0.0,
    ),
    "rimLength": @cli.opt_double(
      base.bell_rim_length_mm,
      help="Cylindrical rim length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "lipRadius": @cli.opt_double(
      base.bell_lip_major_radius_mm,
      help="Rounded-lip major radius in mm",
      min=0.0,
    ),
    "lipMinor": @cli.opt_double(
      base.bell_lip_minor_radius_mm,
      help="Rounded-lip minor radius in mm",
      min=0.0,
    ),
    "hubDiameter": @cli.opt_double(
      base.bell_hub_diameter_mm,
      help="Bell hub diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windows": @cli.opt_int(
      base.window_count,
      help="Number of bell cooling windows",
      min=3,
    ),
    "windowInner": @cli.opt_double(
      base.window_inner_diameter_mm,
      help="Window inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windowOuter": @cli.opt_double(
      base.window_outer_diameter_mm,
      help="Window outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windowInnerAngle": @cli.opt_double(
      base.window_inner_half_angle_deg,
      help="Window inner half-angle in degrees",
      min=0.0,
    ),
    "windowOuterAngle": @cli.opt_double(
      base.window_outer_half_angle_deg,
      help="Window outer half-angle in degrees",
      min=0.0,
    ),
    "windowPhase": @cli.opt_double(
      base.window_phase_deg,
      help="First window phase in degrees",
    ),
    "propHoles": @cli.opt_int(
      base.prop_hole_count,
      help="Number of propeller mounting holes",
      min=1,
    ),
    "propHoleDiameter": @cli.opt_double(
      base.prop_hole_diameter_mm,
      help="Propeller hole diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "propHoleCircle": @cli.opt_double(
      base.prop_hole_circle_diameter_mm,
      help="Propeller hole bolt-circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "statorDiameter": @cli.opt_double(
      base.stator_hub_diameter_mm,
      help="Fixed stator hub diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "statorStart": @cli.opt_double(
      base.stator_hub_start_mm,
      help="Axial start of the stator hub in mm",
      min=0.0,
    ),
    "statorThickness": @cli.opt_double(
      base.stator_hub_thickness_mm,
      help="Stator hub thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mountHoles": @cli.opt_int(
      base.mount_hole_count,
      help="Number of stator mounting holes",
      min=1,
    ),
    "mountHoleDiameter": @cli.opt_double(
      base.mount_hole_diameter_mm,
      help="Stator mounting hole diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mountHoleCircle": @cli.opt_double(
      base.mount_hole_circle_diameter_mm,
      help="Stator mounting hole bolt-circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftDiameter": @cli.opt_double(
      base.shaft_diameter_mm,
      help="Shaft diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftRear": @cli.opt_double(
      base.shaft_rear_extension_mm,
      help="Shaft rear extension in mm",
      min=0.0,
    ),
    "shaftFront": @cli.opt_double(
      base.shaft_front_extension_mm,
      help="Shaft front extension beyond the stator hub in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "evaluated": @cli.flag(
      help="Write the OCCT-evaluated single solid (required for the rounded window cuts)",
    ),
    "bbox": @cli.flag(help="Print the motor bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/brushless_motor",
      description="Generate a parameterized outrunner brushless-motor envelope.",
    )
    is Some(args) else {
    return
  }
  let measured : @motors.BrushlessMotorSpec = {
    bell_outer_diameter_mm: args.double("bellDiameter"),
    bell_wall_thickness_mm: args.double("bellWall"),
    bell_face_outer_diameter_mm: args.double("faceDiameter"),
    bell_face_thickness_mm: args.double("faceThickness"),
    bell_cone_thickness_mm: args.double("coneThickness"),
    bell_cone_run_mm: args.double("coneRun"),
    bell_rim_start_mm: args.double("rimStart"),
    bell_rim_length_mm: args.double("rimLength"),
    bell_lip_major_radius_mm: args.double("lipRadius"),
    bell_lip_minor_radius_mm: args.double("lipMinor"),
    bell_hub_diameter_mm: args.double("hubDiameter"),
    window_count: args.int("windows"),
    window_inner_diameter_mm: args.double("windowInner"),
    window_outer_diameter_mm: args.double("windowOuter"),
    window_inner_half_angle_deg: args.double("windowInnerAngle"),
    window_outer_half_angle_deg: args.double("windowOuterAngle"),
    window_corner_radius_mm: base.window_corner_radius_mm,
    window_phase_deg: args.double("windowPhase"),
    prop_hole_count: args.int("propHoles"),
    prop_hole_diameter_mm: args.double("propHoleDiameter"),
    prop_hole_circle_diameter_mm: args.double("propHoleCircle"),
    stator_hub_diameter_mm: args.double("statorDiameter"),
    stator_hub_start_mm: args.double("statorStart"),
    stator_hub_thickness_mm: args.double("statorThickness"),
    mount_hole_count: args.int("mountHoles"),
    mount_hole_diameter_mm: args.double("mountHoleDiameter"),
    mount_hole_circle_diameter_mm: args.double("mountHoleCircle"),
    shaft_diameter_mm: args.double("shaftDiameter"),
    shaft_rear_extension_mm: args.double("shaftRear"),
    shaft_front_extension_mm: args.double("shaftFront"),
  }
  let part = match @motors.brushless_motor(measured) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if args.flag("evaluated") {
    part.write_step_evaluated(args.string_opt("out"))
  } else {
    part.write_step(args.string_opt("out"), checked=true)
  }
}
