///|
/// 30-desk-cable-tray
///
/// A parametric under-desk cable management tray.
/// Demonstrates profile construction with holes, assembly of multiple parts,
/// and precise text positioning on faces.
///
/// Usage (stdout):
///   moon run --target native examples/30-desk-cable-tray -- --length 200 > tray.step
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(
      200.0,
      help="Total length of the tray (mm)",
      min=50.0,
    ),
    "width": @cli.opt_double(
      60.0,
      help="Width/depth of the tray (mm)",
      min=20.0,
    ),
    "height": @cli.opt_double(
      50.0,
      help="Total height of the tray (mm)",
      min=20.0,
    ),
    "thickness": @cli.opt_double(3.0, help="Material thickness (mm)", min=1.0),
    "mountHoleSpacing": @cli.opt_double(
      120.0,
      help="Spacing between mounting holes (mm)",
      min=20.0,
    ),
    "mountHoleDia": @cli.opt_double(
      5.0,
      help="Diameter of mounting holes (mm)",
      min=1.0,
    ),
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
      prog="30-desk-cable-tray",
      description="Generate a parametric under-desk cable management tray.",
    )
    is Some(args) else {
    return
  }
  let length = args.double("length")
  let width = args.double("width")
  let height = args.double("height")
  let thick = args.double("thickness")
  let m_spacing = args.double("mountHoleSpacing")
  let m_dia = args.double("mountHoleDia")
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

  // 1. Back wall (mounting face)
  // Original XY plane (length x height), extruded by 'thick' in Z.
  // After rotate_x(90): x: 0..length, y: -thick..0, z: 0..height.
  let back_wall_outer = @cad.Profile2D::rect(length, height)
  let m_hole = @cad.Profile2D::circle(m_dia).rev()
  let back_wall_profile = @cad.Profile2D::new(back_wall_outer).add_holes_at(
    [
      (length / 2.0 - m_spacing / 2.0, height / 2.0),
      (length / 2.0 + m_spacing / 2.0, height / 2.0),
    ],
    m_hole,
  )
  let back_wall = @cad.ExtrudedProfile::new(
      back_wall_profile.outer,
      thick,
      holes=back_wall_profile.holes,
    )
    .with_name("back-wall")
    .with_color(@cad.Rgb::new(0.2, 0.3, 0.6))
    .rotate_x(90.0)
    .translate(x=-length / 2.0, y=0.0, z=0.0)

  // 2. Bottom plate
  // Fills the gap between back-wall (y=-thick) and front-lip (y=-width+thick).
  let bottom = @cad.Cuboid::new(length, width - 2.0 * thick, thick)
    .with_name("bottom-plate")
    .with_color(@cad.Rgb::new(0.3, 0.4, 0.7))
    .translate(x=-length / 2.0, y=-width + thick, z=0.0)

  // 3. Front lip
  // Positioned at the very front (min_y).
  let front_lip = @cad.Cuboid::new(length, thick, height * 0.4)
    .with_name("front-lip")
    .with_color(@cad.Rgb::new(0.4, 0.5, 0.8))
    .translate(x=-length / 2.0, y=-width, z=0.0)

  // 4. Labels
  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="desk-cable-tray")
    .add(back_wall)
    .add(bottom)
    .add(front_lip)
    .add_text_on_face(
      front_lip,
      "CABLE TRAY",
      Back, // Outside face (min_y)
      font,
      font_size=height * 0.15,
      color=@cad.Rgb::white(),
    )
    .add_text_on_face(
      back_wall,
      "MOUNTING SIDE",
      Top, // Inside face (local +Z, world -Y)
      font,
      font_size=height * 0.1,
      color=@cad.Rgb::white(),
    )
    .translate(x=tx, y=ty, z=tz)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
