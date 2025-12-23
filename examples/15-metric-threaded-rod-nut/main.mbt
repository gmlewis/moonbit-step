///|
/// 15-metric-threaded-rod-nut
///
/// A working example that generates a STEP model for a nut-like coupler body
/// with correct clearances.
///
/// Usage (stdout):
///   moon run --target native examples/15-metric-threaded-rod-nut -- --boltDiameter 8 --clearance 0.1 > nut-strip.step
async fn main {
  let base_args_spec = {
    "boltDiameter": @cli.opt_double(
      8.0,
      help="Nominal bolt diameter (mm)",
      min=1.0,
    ),
    "clearance": @cli.opt_double(0.1, help="Base clearance (mm)", min=0.0),
    "interference": @cli.opt_double(0.0, help="Base interference (mm)", min=0.0),
    "stepCount": @cli.opt_double(5.0, help="Number of test steps", min=1.0),
    "clearanceStep": @cli.opt_double(
      0.05,
      help="Clearance increment per step (mm)",
    ),
    "holeSpacing": @cli.opt_double(
      20.0,
      help="Spacing between holes (mm)",
      min=5.0,
    ),
    "mountThickness": @cli.opt_double(
      5.0,
      help="Thickness of the base plate (mm)",
      min=1.0,
    ),
    "nutHeight": @cli.opt_double(
      0.0,
      help="Height of the nut (0 for standard)",
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
      prog="15-metric-threaded-rod-nut",
      description="Generate a metric threaded rod nut test strip.",
    )
    is Some(args) else {
    return
  }
  let bolt_diameter = args.double("boltDiameter")
  let clearance = args.double("clearance")
  let interference = args.double("interference")
  let step_count = args.double("stepCount").to_int()
  let clearance_step = args.double("clearanceStep")
  let hole_spacing = args.double("holeSpacing")
  let mount_thickness = args.double("mountThickness")
  let nut_height_opt = args.double("nutHeight")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nut_height = if nut_height_opt > 0.0 {
    Some(nut_height_opt)
  } else {
    None
  }
  let nodes = @cad.metric_nut_test_strip(
    bolt_diameter,
    clearance,
    interference,
    step_count,
    clearance_step,
    hole_spacing,
    mount_thickness,
    nut_height?,
  )
  let mut design = @cad.Design::new(name="metric-threaded-rod-nut")
  for node in nodes {
    design = design.add(node.translate(x=tx, y=ty, z=tz))
  }
  design.write_step(out_path)
}
