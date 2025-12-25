///|
/// 03-engraved-name-tag
///
/// A working example that generates a STEP model for a keychain tag with
/// programmable text placement and border styles.
///
/// Usage (stdout):
///   moon run --target native examples/03-engraved-name-tag -- --name Susan > name-tag.step
///
/// Usage (write file):
///   moon run --target native examples/03-engraved-name-tag -- --name Susan -o name-tag.step
async fn main {
  let base_args_spec = {
    "debug": @cli.flag(short='d', help="Print debug information"),
    "length": @cli.opt_double(
      50.0,
      help="Tag length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      20.0,
      help="Tag width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      12.0,
      help="Tag height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "margin": @cli.opt_double(3.0, help="Font margin (mm)"),
    "embossDepth": @cli.opt_double(
      1.0,
      help="Text emboss height above the tag top (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "name": @cli.opt_string(short='n', help="Name to engrave on the tag"),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="03-engraved-name-tag",
      description="Generate a keychain tag STEP model.",
    )
    is Some(args) else {
    return
  }
  let length_mm = args.double("length")
  let width_mm = args.double("width")
  let height_mm = args.double("height")
  let margin_mm = args.double("margin")
  let emboss_depth_mm = args.double("embossDepth")
  guard args.string_opt("name") is Some(name) else {
    @cli.eprintln("--name is required")
    abort("")
  }
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }
  let font = @baloo.font
  let out_path = args.string_opt("out")

  // Base tag.
  let base = @cad.CalibrationChamferBlock::new(
      length_mm,
      width_mm,
      height_mm,
      chamfer_size_mm=1.0,
      fillet_radius_mm=0.0,
      fillet_segments=10,
    )
    .with_name("tag-base")
    .with_color(@cad.Rgb::new(0.5, 0.0, 0.5)) // purple

  // Text solids using the new helper with auto-scaling
  let design = @cad.Design::new(name="keychain-tag")
    .add(base)
    .add_text_on_face(
      base,
      name,
      Top,
      font,
      margin=margin_mm,
      emboss_depth=emboss_depth_mm,
      color=@cad.Rgb::orange(),
    )
    .translate(x=tx, y=ty, z=tz)
  design.write_step(out_path)
}
