///|
/// 10-polygon-knob
///
/// A parametric polygon knob with a custom polygon hole for a shaft.
///
/// Usage (stdout):
///   moon run --target native examples/10-polygon-knob -- > knob.step
///
/// Usage (write file):
///   moon run --target native examples/10-polygon-knob -- -o knob.step
async fn main {
  let base_args_spec = {
    "sides": @cli.opt_double(
      6.0,
      help="Number of sides for the knob (e.g. 6 for hexagon)",
      min=3.0,
    ),
    "diameter": @cli.opt_double(
      30.0,
      help="Knob outer diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      15.0,
      help="Knob height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "holeSides": @cli.opt_double(
      6.0,
      help="Number of sides for the shaft hole",
      min=3.0,
    ),
    "holeDiameter": @cli.opt_double(
      6.35,
      help="Shaft hole diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "holeRotation": @cli.opt_double(0.0, help="Shaft hole rotation (degrees)"),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="10-polygon-knob",
      description="Generate a parametric polygon knob.",
    )
    is Some(args) else {
    return
  }
  let sides = args.double("sides").to_int()
  let diameter = args.double("diameter")
  let height = args.double("height")
  let hole_sides = args.double("holeSides").to_int()
  let hole_diameter = args.double("holeDiameter")
  let hole_rotation = args.double("holeRotation")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Validate hole fits in knob
  if hole_diameter >= diameter {
    @cli.eprintln("error: holeDiameter must be less than diameter")
    abort("")
  }

  //
  let knob = @cad.polygon_knob(
      sides,
      diameter,
      height,
      hole_sides,
      hole_diameter,
      hole_rotation~,
    )
    .with_name("polygon-knob")
    .with_color(@cad.Rgb::cyan())
    .translate(x=tx, y=ty, z=tz)

  //
  let design = @cad.Design::new(name="polygon-knob").add(knob)
  design.write_step(out_path)
}
