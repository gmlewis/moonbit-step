///|
/// 27-camera-tripod-adapter
///
/// A parametric Arca-Swiss compatible camera tripod mounting plate.
/// This example demonstrates creating a complex cross-section profile
/// and extruding it to create a functional mechanical part.
///
/// Usage (stdout):
///   moon run --target native examples/27-camera-tripod-adapter -- > plate.step
///
/// Usage (write file):
///   moon run --target native examples/27-camera-tripod-adapter -- -o plate.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(
      38.0,
      help="Plate width at the dovetail base (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "length": @cli.opt_double(
      50.0,
      help="Plate length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      10.0,
      help="Total plate height (mm)",
      min=0.0,
      min_exclusive=true,
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
      prog="27-camera-tripod-adapter",
      description="Generate a parametric Arca-Swiss camera tripod mounting plate.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let length = args.double("length")
  let height = args.double("height")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Create the main Arca-Swiss plate body
  let plate = arca_swiss_body(width, length, height)
    .with_name("tripod-plate")
    .with_color(@cad.Rgb::cyan())
    .rotate_x(90.0)
    .translate(y=length / 2.0)

  // Add rubber grip pads on top
  let pad_w = width * 0.2
  let pad_l = length * 0.8
  let pad_h = 1.0
  let pad_color = @cad.Rgb::new(0.1, 0.0, 0.2) // Deep purple
  let left_pad = @cad.Cuboid::new(pad_w, pad_l, pad_h)
    .with_name("left-pad")
    .with_color(pad_color)
    .translate(x=-width * 0.25 - pad_w / 2.0, y=-pad_l / 2.0, z=height / 2.0)
  let right_pad = @cad.Cuboid::new(pad_w, pad_l, pad_h)
    .with_name("right-pad")
    .with_color(pad_color)
    .translate(x=width * 0.25 - pad_w / 2.0, y=-pad_l / 2.0, z=height / 2.0)

  // Add some text branding on top
  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="camera-tripod-adapter")
    .add(plate)
    .add(left_pad)
    .add(right_pad)
    .add_text_on_face(
      plate,
      "ARCA-SWISS",
      Back, // Original min_y face, points DOWN after rotate_x(90)
      font,
      font_size=3.5,
      emboss_depth=0.5,
      offset_y=0.0,
      color=@cad.Rgb::orange(),
    )
    .translate(x=tx, y=ty, z=tz)
    .rotate_y(180.0)
    .rotate_z(180.0)
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn arca_swiss_body(
  width : Double,
  length : Double,
  height : Double,
) -> @cad.Shape {
  let hh = height / 2.0
  let dh = 6.0 // dovetail height
  let dx = dh // 45 degrees
  let w_max = width / 2.0
  let w_min = w_max - dx
  let profile = [
    (-w_max, -hh),
    (w_max, -hh),
    (w_min, -hh + dh),
    (w_min, hh),
    (-w_min, hh),
    (-w_max, -hh + dh),
  ]
  @cad.ExtrudedProfile::new(profile, length)
}
