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
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Create the main Arca-Swiss plate body
  // Profile in XY (Width, Height), Extrude in Z (Length).
  // Rotate -90 on X so Height(Y) becomes Z (up), and Length(Z) becomes Y (front).
  // After rotation, Y is from 0 to Length.
  // We translate by -Length/2 to center it in Y.
  let plate = arca_swiss_body(width, length, height)
    .with_name("tripod-plate")
    .with_color(@cad.Rgb::cyan())
    .rotate_x(-90.0)
    .translate(y=-length / 2.0)

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
  // The pads are 1.0mm high, so we emboss the text 1.5mm so it stands out.
  let font = @baloo.font
  let brand_text = @cad.text_at(
    "ARCA-SWISS",
    0.0,
    0.0,
    height / 2.0,
    font~,
    font_size=4.0,
    emboss_depth=1.5,
  ).map(fn(node) { node.with_color(@cad.Rgb::orange()) })
  let design = @cad.Design::new(name="camera-tripod-adapter")
    .add(plate)
    .add(left_pad)
    .add(right_pad)
    .add_iter(brand_text.iter())
    .translate(x=tx, y=ty, z=tz)
  design.write_step(out_path)
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

  // Profile (looking from front/back)
  // Bottom surface at Y=-hh
  // Top surface at Y=hh
  let profile = [
    (-w_max, -hh), // Bottom-left
    (w_max, -hh), // Bottom-right
    (w_min, -hh + dh), // Dovetail-right
    (w_min, hh), // Top-right
    (-w_min, hh), // Top-left
    (-w_max, -hh + dh), // Dovetail-left
  ]
  @cad.ExtrudedProfile::new(profile, length)
}
