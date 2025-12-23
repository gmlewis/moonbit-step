///|
/// 19-raspberry-pi-mount-plate
///
/// A working example that generates a STEP model for: A mounting plate with
/// programmable hole patterns and cable strain-relief geometry.
///
/// Usage (stdout):
///   moon run --target native examples/19-raspberry-pi-mount-plate -- --width 80 --length 70 > rpi-plate.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(
      85.0,
      help="Width of the mounting plate (mm)",
      min=65.0,
    ),
    "length": @cli.opt_double(
      75.0,
      help="Length of the mounting plate (mm)",
      min=55.0,
    ),
    "thickness": @cli.opt_double(3.0, help="Plate thickness (mm)", min=1.0),
    "holeDiameter": @cli.opt_double(
      3.0,
      help="Mounting hole diameter (mm, RPi standard is 2.75-3.0)",
      min=1.0,
    ),
    "slotLength": @cli.opt_double(
      12.0,
      help="Cable tie slot length (mm)",
      min=5.0,
    ),
    "slotWidth": @cli.opt_double(3.0, help="Cable tie slot width (mm)", min=1.0),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="19-raspberry-pi-mount-plate",
      description="Generate a Raspberry Pi mount plate STEP model.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let length = args.double("length")
  let thickness = args.double("thickness")
  let hole_diameter = args.double("holeDiameter")
  let slot_length = args.double("slotLength")
  let slot_width = args.double("slotWidth")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let plate = @cad.raspberry_pi_mount_plate(
      width, length, thickness, hole_diameter, slot_length, slot_width,
    )
    .with_name("rpi-mount-plate")
    .with_color(@cad.Rgb::green())
    .translate(x=tx - width / 2.0, y=ty - length / 2.0, z=tz)
  let design = @cad.Design::new(name="raspberry-pi-mount-plate").add(plate)
  design.write_step(out_path)
}
