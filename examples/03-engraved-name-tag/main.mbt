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
    "depth": @cli.opt_double(
      1.0,
      help="Text depth/height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "emboss": @cli.flag(help="Emboss text above the tag"),
    "keep": @cli.flag(help="Keep boolean modifiers in Blender output"),
    "name": @cli.opt_string(short='n', help="Name to engrave on the tag"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
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
  let depth_mm = args.double("depth")
  let emboss = args.flag("emboss")
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
  let font = @cad.load_font("baloo")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
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

  //
  let text_design = @cad.Design::new(name="text-only").add_text_on_face(
    base,
    name,
    Top,
    font,
    margin=margin_mm,
    emboss_depth=depth_mm,
    color=@cad.Rgb::orange(),
    emboss~,
  )
  let text_nodes = text_design.nodes

  //
  let design = if emboss {
    @cad.Design::new(name="keychain-tag")
    .add(base)
    .add_iter(text_nodes.iter())
    .translate(x=tx, y=ty, z=tz)
  } else {
    let engraved = @cad.difference(base, text_nodes, name="tag-engraved").with_color(
      @cad.Rgb::new(0.5, 0.0, 0.5),
    )
    @cad.Design::new(name="keychain-tag")
    .add(engraved)
    .translate(x=tx, y=ty, z=tz)
  }
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path, keep_modifiers=args.flag("keep"))
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path, keep_modifiers=args.flag("keep"))
  } else {
    design.write_step(out_path)
  }
}
