///|
/// 04-parametric-washer-kit
///
/// A working example that generates a family of washers from inner/outer diameters.
///
/// Usage (stdout):
///   moon run --target native examples/04-parametric-washer-kit -- --id 5 --od 10 --thickness 1 > washer.step
async fn main {
  let base_args_spec = {
    "id": @cli.opt_double(
      5.0,
      help="Inner diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "od": @cli.opt_double(
      15.0,
      help="Outer diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      2.0,
      help="Washer thickness (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "segments": @cli.opt_double(
      64.0,
      help="Circle segments (smoothness)",
      min=3.0,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="04-parametric-washer-kit",
      description="Generate a parametric washer STEP model.",
    )
    is Some(args) else {
    return
  }
  let id = args.double("id")
  let od = args.double("od")
  let thickness = args.double("thickness")
  let segments = args.double("segments").to_int()
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  if id >= od {
    @cli.eprintln(
      "error: inner diameter (\{id}) must be less than outer diameter (\{od})",
    )
    abort("")
  }

  // Generate circular profiles.
  let outer = @cad.Profile2D::circle(od, segments~)
  let hole = @cad.Profile2D::circle(id, segments~)

  // Create the washer as an extruded profile with a hole.
  let washer = @cad.ExtrudedProfile::new(outer, thickness, holes=[hole])
    .with_name("washer")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty, z=tz)
  let design = @cad.Design::new(name="parametric-washer").add(washer)
  design.write_step(out_path)
}
