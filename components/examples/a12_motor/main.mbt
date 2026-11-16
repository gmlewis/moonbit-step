///|
/// components/examples/a12_motor
///
/// Generate a parameterized XAIRCRAFT A12 8318 100KV outrunner motor
/// envelope. The defaults are the measured motor dimensions (91 mm bell,
/// 33 mm overall height, 23 mm M4 prop circle, 30 mm M3 / 32 mm M4 mount
/// circles, 83 mm x 18 mm stator).
///
/// The large windowed endbell is the **rotor**: attach gears, pulleys, or
/// propellers only through `rotor-output-face`, `rotor-output-hole-*`, or the
/// `rotor-shaft-*` ends. The circular mount plate with the M3/M4 holes is the
/// fixed **stator**: bolt it to the enclosure through `stator-mount-face` and
/// `stator-mount-hole-*`.
///
/// ```bash
/// moon run components/examples/a12_motor -- -o /tmp/a12.step
/// moon run components/examples/a12_motor -- \
///   --bellDiameter 80 --statorDiameter 72 --stackLength 16 \
///   --magnets 36 --teeth 24 --propHoleCircle 20 \
///   -o /tmp/motor80.step
/// ```
///
/// Use `./run-example.sh a12_motor --view` to open the part in SolidCraft.
async fn main {
  let base = @motors.a12_motor_100kv_spec()
  let spec = {
    "bellDiameter": @cli.opt_double(
      base.bell_outer_diameter_mm,
      help="Bell outside diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bellWall": @cli.opt_double(
      base.bell_wall_thickness_mm,
      help="Bell skirt wall thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "skirtLength": @cli.opt_double(
      base.bell_skirt_length_mm,
      help="Bell skirt length from the face plane in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "faceThickness": @cli.opt_double(
      base.bell_face_thickness_mm,
      help="Bell face plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shoulderRadius": @cli.opt_double(
      base.bell_shoulder_radius_mm,
      help="Rounded bell shoulder radius in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bossDiameter": @cli.opt_double(
      base.bell_hub_boss_diameter_mm,
      help="Raised bell hub boss diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bossHeight": @cli.opt_double(
      base.bell_hub_boss_height_mm,
      help="Raised bell hub boss height in mm",
      min=0.0,
    ),
    "bellBore": @cli.opt_double(
      base.bell_hub_bore_diameter_mm,
      help="Bell central bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windows": @cli.opt_int(
      base.bell_window_count,
      help="Number of bell cooling windows",
      min=3,
    ),
    "windowInner": @cli.opt_double(
      base.bell_window_inner_diameter_mm,
      help="Bell window inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windowOuter": @cli.opt_double(
      base.bell_window_outer_diameter_mm,
      help="Bell window outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "windowInnerAngle": @cli.opt_double(
      base.bell_window_inner_half_angle_deg,
      help="Bell window inner half-angle in degrees",
      min=0.0,
    ),
    "windowOuterAngle": @cli.opt_double(
      base.bell_window_outer_half_angle_deg,
      help="Bell window outer half-angle in degrees",
      min=0.0,
    ),
    "windowCorner": @cli.opt_double(
      base.bell_window_corner_radius_mm,
      help="Bell window corner radius in mm",
      min=0.0,
    ),
    "windowPhase": @cli.opt_double(
      base.bell_window_phase_deg,
      help="First bell window phase in degrees",
    ),
    "innerSlots": @cli.opt_int(
      base.bell_inner_slot_count,
      help="Number of inner bell hub slots",
      min=0,
    ),
    "innerSlotInner": @cli.opt_double(
      base.bell_inner_slot_inner_diameter_mm,
      help="Inner bell hub slot inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "innerSlotOuter": @cli.opt_double(
      base.bell_inner_slot_outer_diameter_mm,
      help="Inner bell hub slot outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "innerSlotAngle": @cli.opt_double(
      base.bell_inner_slot_half_angle_deg,
      help="Inner bell hub slot cap-centre half-angle in degrees",
      min=0.0,
    ),
    "magnets": @cli.opt_int(
      base.magnet_count,
      help="Number of rotor magnets",
      min=2,
    ),
    "magnetDiameter": @cli.opt_double(
      base.magnet_outer_diameter_mm,
      help="Rotor magnet ring outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "magnetThickness": @cli.opt_double(
      base.magnet_thickness_mm,
      help="Rotor magnet thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "magnetGap": @cli.opt_double(
      base.magnet_gap_mm,
      help="Circumferential gap between magnets in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "magnetStart": @cli.opt_double(
      base.magnet_start_mm,
      help="Axial start of the magnet ring in mm",
      min=0.0,
    ),
    "magnetLength": @cli.opt_double(
      base.magnet_length_mm,
      help="Rotor magnet axial length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "propDiameter": @cli.opt_double(
      base.prop_adapter_diameter_mm,
      help="Prop adapter diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "propThickness": @cli.opt_double(
      base.prop_adapter_thickness_mm,
      help="Prop adapter thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "propBore": @cli.opt_double(
      base.prop_adapter_bore_diameter_mm,
      help="Prop adapter central bore in mm",
      min=0.0,
      min_exclusive=true,
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
    "propScrews": @cli.opt_int(
      base.prop_screw_count,
      help="Number of prop adapter screws",
      min=1,
    ),
    "propScrewDiameter": @cli.opt_double(
      base.prop_screw_diameter_mm,
      help="Prop adapter screw clearance diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "propScrewCircle": @cli.opt_double(
      base.prop_screw_circle_diameter_mm,
      help="Prop adapter screw bolt-circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "statorDiameter": @cli.opt_double(
      base.stator_outer_diameter_mm,
      help="Stator lamination outside diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "statorInner": @cli.opt_double(
      base.stator_inner_diameter_mm,
      help="Stator lamination bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "stackLength": @cli.opt_double(
      base.stator_stack_length_mm,
      help="Stator lamination stack length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "stackStart": @cli.opt_double(
      base.stator_stack_start_mm,
      help="Axial start of the lamination stack in mm",
      min=0.0,
    ),
    "teeth": @cli.opt_int(
      base.stator_tooth_count,
      help="Number of stator teeth and windings",
      min=3,
    ),
    "toothWidth": @cli.opt_double(
      base.stator_tooth_width_mm,
      help="Stator tooth width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "slotFloor": @cli.opt_double(
      base.stator_slot_floor_diameter_mm,
      help="Stator slot floor diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coilInner": @cli.opt_double(
      base.coil_radial_inner_diameter_mm,
      help="Winding band inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coilOuter": @cli.opt_double(
      base.coil_radial_outer_diameter_mm,
      help="Winding band outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coilWidth": @cli.opt_double(
      base.coil_width_mm,
      help="Winding frame tangential width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coilOverhang": @cli.opt_double(
      base.coil_axial_overhang_mm,
      help="Winding end-turn overhang beyond the stack in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plateDiameter": @cli.opt_double(
      base.stator_plate_diameter_mm,
      help="Stator mount plate diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plateThickness": @cli.opt_double(
      base.stator_plate_thickness_mm,
      help="Stator mount plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plateStart": @cli.opt_double(
      base.stator_plate_start_mm,
      help="Axial start of the stator mount plate in mm",
      min=0.0,
    ),
    "plateWindows": @cli.opt_int(
      base.stator_plate_window_count,
      help="Number of stator plate windows",
      min=3,
    ),
    "plateWindowInner": @cli.opt_double(
      base.stator_plate_window_inner_diameter_mm,
      help="Stator plate window inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plateWindowOuter": @cli.opt_double(
      base.stator_plate_window_outer_diameter_mm,
      help="Stator plate window outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plateWindowInnerAngle": @cli.opt_double(
      base.stator_plate_window_inner_half_angle_deg,
      help="Stator plate window inner half-angle in degrees",
      min=0.0,
    ),
    "plateWindowOuterAngle": @cli.opt_double(
      base.stator_plate_window_outer_half_angle_deg,
      help="Stator plate window outer half-angle in degrees",
      min=0.0,
    ),
    "plateWindowCorner": @cli.opt_double(
      base.stator_plate_window_corner_radius_mm,
      help="Stator plate window corner radius in mm",
      min=0.0,
    ),
    "mountM3": @cli.opt_int(
      base.mount_m3_count,
      help="Number of M3 stator mounting holes",
      min=1,
    ),
    "m3Diameter": @cli.opt_double(
      base.mount_m3_hole_diameter_mm,
      help="M3 mounting hole clearance diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "m3Circle": @cli.opt_double(
      base.mount_m3_circle_diameter_mm,
      help="M3 mounting hole bolt-circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mountM4": @cli.opt_int(
      base.mount_m4_count,
      help="Number of M4 stator mounting holes",
      min=1,
    ),
    "m4Diameter": @cli.opt_double(
      base.mount_m4_hole_diameter_mm,
      help="M4 mounting hole clearance diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "m4Circle": @cli.opt_double(
      base.mount_m4_circle_diameter_mm,
      help="M4 mounting hole bolt-circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bearingTube": @cli.opt_double(
      base.bearing_tube_outer_diameter_mm,
      help="Bearing tube outside diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bearingBore": @cli.opt_double(
      base.bearing_bore_diameter_mm,
      help="Bearing bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pcbInner": @cli.opt_double(
      base.pcb_ring_inner_diameter_mm,
      help="Insulator ring inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pcbOuter": @cli.opt_double(
      base.pcb_ring_outer_diameter_mm,
      help="Insulator ring outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pcbThickness": @cli.opt_double(
      base.pcb_thickness_mm,
      help="Insulator ring thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftDiameter": @cli.opt_double(
      base.shaft_diameter_mm,
      help="Shaft diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftFront": @cli.opt_double(
      base.shaft_front_extension_mm,
      help="Shaft overhang beyond the prop face in mm",
      min=0.0,
    ),
    "shaftRear": @cli.opt_double(
      base.shaft_rear_extension_mm,
      help="Shaft overhang beyond the mount face in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "evaluated": @cli.flag(
      help="Write the OCCT-evaluated compound instead of the flat analytic STEP",
    ),
    "bbox": @cli.flag(help="Print the motor bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/a12_motor",
      description="Generate a parameterized A12 8318 outrunner motor envelope.",
    )
    is Some(args) else {
    return
  }
  let measured : @motors.A12MotorSpec = {
    bell_outer_diameter_mm: args.double("bellDiameter"),
    bell_wall_thickness_mm: args.double("bellWall"),
    bell_skirt_length_mm: args.double("skirtLength"),
    bell_face_thickness_mm: args.double("faceThickness"),
    bell_shoulder_radius_mm: args.double("shoulderRadius"),
    bell_hub_boss_diameter_mm: args.double("bossDiameter"),
    bell_hub_boss_height_mm: args.double("bossHeight"),
    bell_hub_bore_diameter_mm: args.double("bellBore"),
    bell_window_count: args.int("windows"),
    bell_window_inner_diameter_mm: args.double("windowInner"),
    bell_window_outer_diameter_mm: args.double("windowOuter"),
    bell_window_inner_half_angle_deg: args.double("windowInnerAngle"),
    bell_window_outer_half_angle_deg: args.double("windowOuterAngle"),
    bell_window_corner_radius_mm: args.double("windowCorner"),
    bell_window_phase_deg: args.double("windowPhase"),
    bell_inner_slot_count: args.int("innerSlots"),
    bell_inner_slot_inner_diameter_mm: args.double("innerSlotInner"),
    bell_inner_slot_outer_diameter_mm: args.double("innerSlotOuter"),
    bell_inner_slot_half_angle_deg: args.double("innerSlotAngle"),
    bell_inner_slot_phase_deg: base.bell_inner_slot_phase_deg,
    magnet_count: args.int("magnets"),
    magnet_outer_diameter_mm: args.double("magnetDiameter"),
    magnet_thickness_mm: args.double("magnetThickness"),
    magnet_gap_mm: args.double("magnetGap"),
    magnet_start_mm: args.double("magnetStart"),
    magnet_length_mm: args.double("magnetLength"),
    magnet_phase_deg: base.magnet_phase_deg,
    prop_adapter_diameter_mm: args.double("propDiameter"),
    prop_adapter_thickness_mm: args.double("propThickness"),
    prop_adapter_bore_diameter_mm: args.double("propBore"),
    prop_hole_count: args.int("propHoles"),
    prop_hole_diameter_mm: args.double("propHoleDiameter"),
    prop_hole_circle_diameter_mm: args.double("propHoleCircle"),
    prop_hole_phase_deg: base.prop_hole_phase_deg,
    prop_screw_count: args.int("propScrews"),
    prop_screw_diameter_mm: args.double("propScrewDiameter"),
    prop_screw_circle_diameter_mm: args.double("propScrewCircle"),
    stator_outer_diameter_mm: args.double("statorDiameter"),
    stator_inner_diameter_mm: args.double("statorInner"),
    stator_stack_length_mm: args.double("stackLength"),
    stator_stack_start_mm: args.double("stackStart"),
    stator_tooth_count: args.int("teeth"),
    stator_tooth_width_mm: args.double("toothWidth"),
    stator_slot_floor_diameter_mm: args.double("slotFloor"),
    stator_tooth_phase_deg: base.stator_tooth_phase_deg,
    coil_radial_inner_diameter_mm: args.double("coilInner"),
    coil_radial_outer_diameter_mm: args.double("coilOuter"),
    coil_width_mm: args.double("coilWidth"),
    coil_axial_overhang_mm: args.double("coilOverhang"),
    coil_corner_radius_mm: base.coil_corner_radius_mm,
    coil_inner_corner_radius_mm: base.coil_inner_corner_radius_mm,
    stator_plate_diameter_mm: args.double("plateDiameter"),
    stator_plate_thickness_mm: args.double("plateThickness"),
    stator_plate_start_mm: args.double("plateStart"),
    stator_plate_window_count: args.int("plateWindows"),
    stator_plate_window_inner_diameter_mm: args.double("plateWindowInner"),
    stator_plate_window_outer_diameter_mm: args.double("plateWindowOuter"),
    stator_plate_window_inner_half_angle_deg: args.double(
      "plateWindowInnerAngle",
    ),
    stator_plate_window_outer_half_angle_deg: args.double(
      "plateWindowOuterAngle",
    ),
    stator_plate_window_corner_radius_mm: args.double("plateWindowCorner"),
    stator_plate_window_phase_deg: base.stator_plate_window_phase_deg,
    mount_m3_count: args.int("mountM3"),
    mount_m3_hole_diameter_mm: args.double("m3Diameter"),
    mount_m3_circle_diameter_mm: args.double("m3Circle"),
    mount_m4_count: args.int("mountM4"),
    mount_m4_hole_diameter_mm: args.double("m4Diameter"),
    mount_m4_circle_diameter_mm: args.double("m4Circle"),
    mount_hole_phase_deg: base.mount_hole_phase_deg,
    bearing_tube_outer_diameter_mm: args.double("bearingTube"),
    bearing_bore_diameter_mm: args.double("bearingBore"),
    pcb_ring_inner_diameter_mm: args.double("pcbInner"),
    pcb_ring_outer_diameter_mm: args.double("pcbOuter"),
    pcb_thickness_mm: args.double("pcbThickness"),
    shaft_diameter_mm: args.double("shaftDiameter"),
    shaft_front_extension_mm: args.double("shaftFront"),
    shaft_rear_extension_mm: args.double("shaftRear"),
  }
  let part = match @motors.a12_motor(measured) {
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
