///|
/// 21-breadboard-rail-clips
///
/// A working example that generates a STEP model for: Clips that hold
/// breadboards to rails, generated for multiple breadboard sizes.
///
/// Usage (stdout):
///   moon run --target native examples/21-breadboard-rail-clips -- --width 54.5 > clip.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(54.5, help="Breadboard width (mm)", min=10.0),
    "height": @cli.opt_double(10.0, help="Clip side height (mm)", min=2.0),
    "armThickness": @cli.opt_double(
      2.5,
      help="Thickness of the clip arms (mm)",
      min=1.0,
    ),
    "snapClearance": @cli.opt_double(
      0.2,
      help="Clearance for the snap fit (mm)",
    ),
    "hookDepth": @cli.opt_double(
      2.0,
      help="Depth of the retention hook (mm)",
      min=0.5,
    ),
    "seatDiameter": @cli.opt_double(
      4.0,
      help="Diameter of the rail mounting seat (mm)",
      min=0.0,
    ),
    "seatDepth": @cli.opt_double(
      2.0,
      help="Depth of the rail mounting seat (mm)",
      min=0.0,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="21-breadboard-rail-clips",
      description="Generate a breadboard rail clip STEP model.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let height = args.double("height")
  let arm_thickness = args.double("armThickness")
  let snap_clearance = args.double("snapClearance")
  let hook_depth = args.double("hookDepth")
  let seat_diameter = args.double("seatDiameter")
  let seat_depth = args.double("seatDepth")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = breadboard_rail_clip(
    width, height, arm_thickness, snap_clearance, hook_depth, seat_diameter, seat_depth,
  )
  let mut design = @cad.Design::new(name="breadboard-rail-clip")
  for node in nodes {
    design = design.add(node.translate(x=tx, y=ty, z=tz))
  }
  design.rotate_x(90.0).write_step(out_path)
}

///|
fn breadboard_rail_clip(
  breadboard_width : Double,
  clip_height : Double,
  arm_thickness : Double,
  snap_clearance : Double,
  hook_depth : Double,
  rail_seat_diameter : Double,
  rail_seat_depth : Double,
) -> Array[@cad.SceneNode] {
  let hw = breadboard_width / 2.0

  // Profile in XY plane (will be rotated to XZ)
  // Inside is at Y in [0, clip_height]
  // Bottom plate is at Y in [-arm_thickness, 0]
  let profile = [
    (-hw - arm_thickness, clip_height + arm_thickness),
    (-hw - arm_thickness, -arm_thickness),
    (hw + arm_thickness, -arm_thickness),
    (hw + arm_thickness, clip_height + arm_thickness),
    (hw + arm_thickness - hook_depth, clip_height + arm_thickness),
    (hw + arm_thickness - hook_depth, clip_height),
    (hw + snap_clearance, clip_height),
    (hw + snap_clearance, 0.0),
    (-hw - snap_clearance, 0.0),
    (-hw - snap_clearance, clip_height),
    (-hw - arm_thickness + hook_depth, clip_height),
    (-hw - arm_thickness + hook_depth, clip_height + arm_thickness),
  ]
  let clip_length = 15.0
  let main_clip = @cad.ExtrudedProfile::new(profile, clip_length)
    .with_name("main-clip")
    .with_color(@cad.Rgb::cyan())
    .rotate_x(90.0)
    .translate(y=clip_length / 2.0)
  let nodes = [main_clip]
  if rail_seat_diameter > 0.0 && rail_seat_depth > 0.0 {
    // Two mounting pegs for stability
    let seat_dist = clip_length / 2.0 - rail_seat_diameter
    let seat_locs = [(-seat_dist, 0.0), (seat_dist, 0.0)]
    for i, loc in seat_locs {
      let (sy, _) = loc // Centered along World Y (clip length)
      let seat = @cad.tube(rail_seat_diameter, 0.0, rail_seat_depth)
        .with_name("rail-seat-\{i}")
        .with_color(@cad.Rgb::blue())
        .translate(x=0.0, y=sy, z=-arm_thickness - rail_seat_depth)
      nodes.push(seat)
    }
  }
  nodes
}
