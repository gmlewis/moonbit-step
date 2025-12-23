///|
// 09-dovetail-slider-jig
//
// A parametric dovetail slider jig, demonstrating how to create
// matching parts with clearances using extruded profiles.
//
// Usage (stdout):
//   moon run --target native examples/09-dovetail-slider-jig -- > jig.step
//
// Usage (write file):
//   moon run --target native examples/09-dovetail-slider-jig -- -o jig.step

///|
async fn main {
  let base_args_spec = {
    "baseWidth": @cli.opt_double(
      50.0,
      help="Base block width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "baseHeight": @cli.opt_double(
      15.0,
      help="Base block height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "baseLength": @cli.opt_double(
      100.0,
      help="Base block length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "dovetailWidth": @cli.opt_double(
      20.0,
      help="Dovetail neck width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "dovetailHeight": @cli.opt_double(
      8.0,
      help="Dovetail groove depth (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "dovetailAngle": @cli.opt_double(
      14.0,
      help="Dovetail angle (degrees from vertical)",
      min=0.0,
      max=45.0,
    ),
    "sliderLength": @cli.opt_double(
      40.0,
      help="Slider length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "sliderPos": @cli.opt_double(
      30.0,
      help="Slider position along the base (mm)",
    ),
    "clearance": @cli.opt_double(
      0.1,
      help="Clearance between slider and base (mm)",
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
      prog="09-dovetail-slider-jig",
      description="Generate a parametric dovetail slider jig.",
    )
    is Some(args) else {
    return
  }
  let base_width = args.double("baseWidth")
  let base_height = args.double("baseHeight")
  let base_length = args.double("baseLength")
  let dovetail_width = args.double("dovetailWidth")
  let dovetail_height = args.double("dovetailHeight")
  let dovetail_angle = args.double("dovetailAngle")
  let slider_length = args.double("sliderLength")
  let slider_pos = args.double("sliderPos")
  let clearance = args.double("clearance")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Validate dovetail fits in base
  if dovetail_width >= base_width {
    @cli.eprintln("error: dovetailWidth must be less than baseWidth")
    abort("")
  }
  if dovetail_height >= base_height {
    @cli.eprintln("error: dovetailHeight must be less than baseHeight")
    abort("")
  }
  let base = @cad.dovetail_base(
      base_width, base_height, base_length, dovetail_width, dovetail_height, dovetail_angle,
    )
    .with_name("dovetail-base")
    .with_color(@cad.Rgb::purple())
    .translate(x=tx, y=ty, z=tz)

  // Slider position: 
  // - Centered in X (same as base)
  // - Neck of slider is at Y = base_height / 2 (top of base)
  // - Slider points downwards into the groove.
  let slider = @cad.dovetail_slider(
      dovetail_width,
      dovetail_height,
      slider_length,
      dovetail_angle,
      clearance~,
    )
    .with_name("dovetail-slider")
    .with_color(@cad.Rgb::orange())
    .translate(x=tx, y=ty + base_height / 2.0, z=tz + slider_pos)
  let design = @cad.Design::new(name="dovetail-slider-jig")
    .add(base)
    .add(slider)
  design.write_step(out_path)
}
