///|
/// 17-living-hinge-sample
///
/// A working example that generates a STEP model for a living hinge sample.
///
/// Usage (stdout):
///   moon run --target native examples/17-living-hinge-sample -- --thickness 2 > hinge.step
async fn main {
  let base_args_spec = {
    "plateLength": @cli.opt_double(
      30.0,
      help="Length of the solid plates on either side (mm)",
      min=1.0,
    ),
    "width": @cli.opt_double(
      50.0,
      help="Total width of the hinge (mm)",
      min=1.0,
    ),
    "thickness": @cli.opt_double(2.0, help="Material thickness (mm)", min=0.1),
    "hingeWidth": @cli.opt_double(
      20.0,
      help="Width of the slotted hinge section (mm)",
      min=1.0,
    ),
    "slotWidth": @cli.opt_double(1.0, help="Width of each slot (mm)", min=0.1),
    "slotLength": @cli.opt_double(
      10.0,
      help="Length of each slot (mm)",
      min=1.0,
    ),
    "numRows": @cli.opt_double(7.0, help="Number of rows of slots", min=1.0),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="17-living-hinge-sample",
      description="Generate a living hinge sample STEP model.",
    )
    is Some(args) else {
    return
  }
  let plate_length = args.double("plateLength")
  let width = args.double("width")
  let thickness = args.double("thickness")
  let hinge_width = args.double("hingeWidth")
  let slot_width = args.double("slotWidth")
  let slot_length = args.double("slotLength")
  let num_rows = args.double("numRows").to_int()
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let hinge = @cad.living_hinge(
      plate_length, width, thickness, hinge_width, slot_width, slot_length, num_rows,
    )
    .with_name("living-hinge")
    .with_color(@cad.Rgb::purple())
    .translate(x=tx, y=ty, z=tz)
  let design = @cad.Design::new(name="living-hinge-sample").add(hinge)
  design.write_step(out_path)
}
