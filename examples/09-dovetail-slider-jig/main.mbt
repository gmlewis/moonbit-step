///|
/// 09-dovetail-slider-jig
///
/// A parametric dovetail slider jig, demonstrating how to create
/// matching parts with clearances using extruded profiles.
///
/// Usage (stdout):
///   moon run --target native examples/09-dovetail-slider-jig -- > jig.step
///
/// Usage (write file):
///   moon run --target native examples/09-dovetail-slider-jig -- -o jig.step
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
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
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
  let bpy_path = args.string_opt("bpy")
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
  let base = dovetail_base(
      base_width, base_height, base_length, dovetail_width, dovetail_height, dovetail_angle,
    )
    .with_name("dovetail-base")
    .with_color(@cad.Rgb::purple())
    .translate(x=tx, y=ty, z=tz)

  // Slider position:
  // - Centered in X (same as base)
  // - Neck of slider is at Y = base_height / 2 (top of base)
  // - Slider points downwards into the groove.
  let slider = dovetail_slider(
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
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn dovetail_base(
  width : Double,
  height : Double,
  length : Double,
  dovetail_width : Double,
  dovetail_height : Double,
  dovetail_angle : Double,
) -> @cad.Shape {
  let hw = width / 2.0
  let hh = height / 2.0
  let dhw = dovetail_width / 2.0
  let angle_rad = dovetail_angle * @math.PI / 180.0
  let dx = dovetail_height * @math.tan(angle_rad)

  // Construct a single CCW loop including the dovetail cutout at the top.
  let outer = [
    (-hw, hh),
    (-hw, -hh),
    (hw, -hh),
    (hw, hh),
    (dhw, hh),
    (dhw + dx, hh - dovetail_height),
    (-dhw - dx, hh - dovetail_height),
    (-dhw, hh),
  ]
  @cad.ExtrudedProfile::new(outer, length)
}

///|
fn dovetail_slider(
  width : Double,
  height : Double,
  length : Double,
  angle : Double,
  clearance? : Double = 0.0,
) -> @cad.Shape {
  // Apply clearance: narrow the width and shorten the height.
  let c = clearance
  let w = width - 2.0 * c
  let h = height - c
  let angle_rad = angle * @math.PI / 180.0
  let dx = h * @math.tan(angle_rad)
  let half_width = w / 2.0
  let dt = [
    (-half_width, 0.0),
    (half_width, 0.0),
    (half_width + dx, h),
    (-half_width - dx, h),
  ]
  // Flip Y to match the groove orientation (neck at the top, pointing down).
  // We also reverse the order to maintain CCW orientation.
  let n = dt.length()
  let flipped = []
  for i in 0..<n {
    let p = dt[n - 1 - i]
    flipped.push((p.0, -p.1))
  }
  @cad.ExtrudedProfile::new(flipped, length)
}
