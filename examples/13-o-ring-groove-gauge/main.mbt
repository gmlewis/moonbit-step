///|
/// 13-o-ring-groove-gauge
///
/// A parametric gauge for verifying O-ring groove dimensions.
/// Contains several standard groove sizes based on AS568 cross-sections.
///
/// Usage (stdout):
///   moon run --target native examples/13-o-ring-groove-gauge -- > gauge.step
///
/// Usage (write file):
///   moon run --target native examples/13-o-ring-groove-gauge -- -o gauge.step
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(
      80.0,
      help="Length of the gauge block (mm)",
      min=10.0,
    ),
    "width": @cli.opt_double(
      60.0,
      help="Width of the gauge block (mm)",
      min=10.0,
    ),
    "height": @cli.opt_double(
      10.0,
      help="Height of the gauge block (mm)",
      min=5.0,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="13-o-ring-groove-gauge",
      description="Generate a parametric O-ring groove gauge.",
    )
    is Some(args) else {
    return
  }
  let block_length = args.double("length")
  let block_width = args.double("width")
  let notched_height = args.double("height")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  //
  // Standard AS568 O-ring cross-sections and typical groove dimensions
  // (cross_section, groove_width, groove_depth)
  let standards = [
    (1.78, 2.4, 1.4),
    (2.62, 3.6, 2.25),
    (3.53, 4.8, 3.1),
    (5.33, 7.1, 4.75),
    (6.99, 9.5, 6.25),
  ]

  //
  // Calculate notch positions by distributing remaining space as equal walls.
  let mut total_groove_width = 0.0
  for s in standards {
    total_groove_width += s.1
  }
  let total_wall_width = block_width - total_groove_width
  let wall_count = standards.length() + 1
  let wall_size = total_wall_width / Double::from_int(wall_count)
  if wall_size < 1.0 {
    @cli.eprintln(
      "error: block width (\{block_width}) is too small for these grooves (min wall 1.0mm)",
    )
    abort("")
  }
  let notches = []
  let mut current_x = wall_size
  for i in 0..<standards.length() {
    let (_, w, d) = standards[i]
    notches.push((current_x, w, d))
    current_x += w + wall_size
  }

  //
  // 1. The notched block.
  // We rotate it 90 around X and 180 around Z so it lies flat on the XY plane
  // with the notches facing UP (+Z).
  // Local X (Width) -> World -X (centered)
  // Local Y (Height) -> World Z
  // Local Z (Length) -> World Y
  let gauge = @cad.notched_block(
      block_width, block_length, notched_height, notches,
    )
    .with_name("gauge-notches")
    .with_color(@cad.Rgb::orange())
    .rotate_x(90.0)
    .rotate_z(180.0)
    .translate(x=tx, y=ty, z=tz)

  //
  let design = @cad.Design::new(name="o-ring-groove-gauge").add(gauge)
  design.write_step(out_path)
}
