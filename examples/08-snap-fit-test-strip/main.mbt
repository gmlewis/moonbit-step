///|
/// 08-snap-fit-test-strip
///
/// A working example that generates a STEP model for a snap-fit test strip.
/// It creates a series of cantilever snap arms and matching receiver slots
/// with varying interference levels to test print tolerances.
///
/// Usage (stdout):
///   moon run --target native examples/08-snap-fit-test-strip -- --interference 0.5 > test-strip.step
async fn main {
  let base_args_spec = {
    "clearance": @cli.opt_double(
      0.2,
      help="Nominal clearance between arm and receiver (mm)",
      min=0.0,
    ),
    "interference": @cli.opt_double(
      0.4,
      help="Base hook interference (mm)",
      min=0.0,
    ),
    "stepCount": @cli.opt_double(5.0, help="Number of test steps", min=1.0),
    "interferenceStep": @cli.opt_double(
      0.1,
      help="Amount to increase interference at each step (mm)",
    ),
    "snapClearance": @cli.opt_double(
      0.5,
      help="Vertical engage clearance (mm)",
      min=0.0,
    ),
    "armThickness": @cli.opt_double(
      1.5,
      help="Cantilever arm thickness (mm)",
      min=0.5,
    ),
    "armWidth": @cli.opt_double(10.0, help="Snap arm width (mm)", min=2.0),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="08-snap-fit-test-strip",
      description="Generate a snap-fit tolerance test strip.",
    )
    is Some(args) else {
    return
  }
  let clearance = args.double("clearance")
  let base_interference = args.double("interference")
  let step_count = args.double("stepCount").to_int()
  let interference_step = args.double("interferenceStep")
  let snap_clearance = args.double("snapClearance")
  let arm_thickness = args.double("armThickness")
  let arm_width = args.double("armWidth")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }

  // Constants
  let arm_height = 20.0
  let base_height = 5.0
  let step_spacing = arm_width + 10.0
  let receiver_length = 15.0
  let hook_height = 3.0
  let mut design = @cad.Design::new(name="snap-fit-test")

  // 1. Generate the test strip (Arms)
  let strip_length = Double::from_int(step_count) * step_spacing
  let arm_base_strip = @cad.Cuboid::new(strip_length, 15.0, base_height)
    .with_name("arm-base")
    .with_color(@cad.Rgb::cyan())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(arm_base_strip)
  for i in 0..<step_count {
    let x_offset = Double::from_int(i) * step_spacing + step_spacing / 2.0
    let current_interference = base_interference +
      Double::from_int(i) * interference_step

    // The Arm Profile (side view in XZ plane)
    // X = thickness, Y = height (will become Z)
    let arm_poly = [
      (0.0, 0.0),
      (arm_thickness, 0.0),
      (arm_thickness, arm_height - hook_height),
      (arm_thickness + current_interference, arm_height - hook_height / 2.0),
      (arm_thickness, arm_height),
      (0.0, arm_height),
    ]
    let arm = @cad.ExtrudedProfile::new(arm_poly, arm_width)
      .with_name("arm-\{i}")
      .with_color(@cad.Rgb::orange())
      // ExtrudedProfile is in XY, extruding along Z.
      // We want:
      // Local Y (Height) -> World Z (Up)
      // Local Z (Width) -> World X (Along strip)
      // Local X (Thickness) -> World Y (Across strips)
      .rotate_x(90.0) // Local Y -> World Z, Local Z -> World -Y
      .rotate_z(90.0) // World X -> World Y, World -Y -> World X
      .translate(
        x=tx + x_offset - arm_width / 2.0,
        y=ty + 7.5 - arm_thickness / 2.0,
        z=tz + base_height,
      )
    design = design.add(arm)
  }

  // 2. Generate the Receiver Strip
  let receiver_y_offset = 30.0
  let receiver_base_strip = @cad.Cuboid::new(
      strip_length, receiver_length, base_height,
    )
    .with_name("receiver-base")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty + receiver_y_offset, z=tz)
  design = design.add(receiver_base_strip)
  for i in 0..<step_count {
    let x_offset = Double::from_int(i) * step_spacing + step_spacing / 2.0

    // Build the receiver "cage" growing UP from the base

    // Back wall
    let back_wall = @cad.Cuboid::new(arm_width + 4.0, 2.0, arm_height)
      .with_name("recv-back-\{i}")
      .with_color(@cad.Rgb::blue())
      .translate(
        x=tx + x_offset - (arm_width + 4.0) / 2.0,
        y=ty + receiver_y_offset,
        z=tz + base_height,
      )
    design = design.add(back_wall)

    // Side walls
    let side_wall_l = @cad.Cuboid::new(2.0, 8.0, arm_height)
      .with_name("recv-side-l-\{i}")
      .with_color(@cad.Rgb::blue())
      .translate(
        x=tx + x_offset - (arm_width + 4.0) / 2.0,
        y=ty + receiver_y_offset + 2.0,
        z=tz + base_height,
      )
    design = design.add(side_wall_l)
    let side_wall_r = @cad.Cuboid::new(2.0, 8.0, arm_height)
      .with_name("recv-side-r-\{i}")
      .with_color(@cad.Rgb::blue())
      .translate(
        x=tx + x_offset + arm_width / 2.0,
        y=ty + receiver_y_offset + 2.0,
        z=tz + base_height,
      )
    design = design.add(side_wall_r)

    // The "ledge" the snap hooks onto
    let ledge_height = 3.0
    let ledge = @cad.Cuboid::new(arm_width, 2.0, ledge_height)
      .with_name("recv-ledge-\{i}")
      .with_color(@cad.Rgb::red())
      .translate(
        x=tx + x_offset - arm_width / 2.0,
        y=ty + receiver_y_offset + 2.0 + arm_thickness + clearance,
        z=tz + base_height + arm_height - ledge_height - snap_clearance,
      )
    design = design.add(ledge)
  }
  design.write_step(out_path)
}
