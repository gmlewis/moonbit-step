///|
/// 07-cable-label-clip
///
/// A snap-on cable label clip with programmable text.
///
/// Usage (stdout):
///   moon run --target native examples/07-cable-label-clip -- --diameter 5 --text USB > clip.step
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(6.0, help="Cable diameter (mm)", min=1.0),
    "text": @cli.opt_string(short='t', help="Label text"),
    "length": @cli.opt_double(20.0, help="Clip length (mm)", min=5.0),
    "thickness": @cli.opt_double(1.5, help="Clip wall thickness (mm)", min=0.5),
    "opening": @cli.opt_double(
      100.0,
      help="Opening angle (degrees)",
      min=10.0,
      max=120.0,
    ),
    "fontSize": @cli.opt_double(0.0, help="Font size", min=0.0),
    "depth": @cli.opt_double(0.5, help="Engraving depth (mm)", min=0.0),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
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
      prog="07-cable-label-clip",
      description="Generate a snap-on cable label clip.",
    )
    is Some(args) else {
    return
  }
  let diameter = args.double("diameter")
  let label_text = args.string_opt("text").unwrap_or("LABEL")
  let clip_length = args.double("length")
  let wall = args.double("thickness")
  let opening_deg = args.double("opening")
  let emboss_depth = args.double("depth")
  let font_size_opt = args.double("fontSize")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let mut design = @cad.Design::new(name="cable-label")

  //
  let open_rad = opening_deg * @math.PI / 180.0
  // Opening faces -Y (front)
  let start_angle = -(@math.PI / 2.0) + open_rad / 2.0
  let end_angle = 3.0 * @math.PI / 2.0 - open_rad / 2.0
  let outer_arc = @cad.Profile2D::arc(
    diameter + 2.0 * wall,
    start_angle,
    end_angle,
    segments=32,
  )
  let inner_arc = @cad.Profile2D::arc(
    diameter,
    start_angle,
    end_angle,
    segments=32,
  )

  //
  let c_profile : Array[(Double, Double)] = []
  c_profile.push_iter(outer_arc.iter())
  c_profile.push_iter(inner_arc.rev().iter())

  // 1. The C-clip body (extruded along Z)
  let clip_body = @cad.ExtrudedProfile::new(c_profile, clip_length)
    .with_name("clip-body")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(clip_body)

  // 2. Label Plaque
  let plaque_width = diameter + wall
  let plaque_thickness = wall
  let plaque = @cad.Cuboid::new(plaque_width, plaque_thickness, clip_length)
    .with_name("label-plaque")
    .with_color(@cad.Rgb::green())
    .translate(x=tx - plaque_width / 2.0, y=ty + diameter / 2.0, z=tz)
  design = design.add(plaque)

  // 3. Text
  let font = @cad.load_font("baloo")
  if font_size_opt > 0.0 {
    design = design.add_text_on_face(
      plaque,
      label_text,
      Top,
      font,
      font_size=font_size_opt,
      emboss_depth~,
      color=@cad.Rgb::orange(),
    )
  } else {
    design = design.add_text_on_face(
      plaque,
      label_text,
      Top,
      font,
      emboss_depth~,
      color=@cad.Rgb::orange(),
    )
  }

  //
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
