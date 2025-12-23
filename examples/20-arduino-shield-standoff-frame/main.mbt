///|
/// 20-arduino-shield-standoff-frame
///
/// A working example that generates a STEP model for: A standoff frame that
/// supports stacked boards with computed clearances.
///
/// Usage (stdout):
///   moon run --target native examples/20-arduino-shield-standoff-frame -- --standoffHeight 10 > arduino-frame.step
async fn main {
  let base_args_spec = {
    "frameThickness": @cli.opt_double(
      3.0,
      help="Thickness of the base frame (mm)",
      min=1.0,
    ),
    "standoffHeight": @cli.opt_double(
      10.0,
      help="Height of the standoffs (mm)",
      min=1.0,
    ),
    "standoffOD": @cli.opt_double(
      6.0,
      help="Outer diameter of standoffs (mm)",
      min=1.0,
    ),
    "standoffID": @cli.opt_double(
      3.2,
      help="Inner hole diameter of standoffs (mm)",
      min=0.5,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="20-arduino-shield-standoff-frame",
      description="Generate an Arduino Uno standoff frame STEP model.",
    )
    is Some(args) else {
    return
  }
  let frame_thickness = args.double("frameThickness")
  let standoff_height = args.double("standoffHeight")
  let standoff_od = args.double("standoffOD")
  let standoff_id = args.double("standoffID")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = @cad.arduino_uno_standoff_frame(
    frame_thickness, standoff_height, standoff_od, standoff_id,
  )
  let mut design = @cad.Design::new(name="arduino-standoff-frame")
  for node in nodes {
    // Center the board area approximately
    design = design.add(
      node.translate(x=tx - 68.6 / 2.0, y=ty - 53.3 / 2.0, z=tz),
    )
  }
  design.write_step(out_path)
}
