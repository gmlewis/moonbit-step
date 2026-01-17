///|
/// 05-gridfinity-compatible-bin
///
/// A maker-friendly storage bin generator.
///
/// Usage (stdout):
///   moon run --target native examples/05-gridfinity-compatible-bin -- --rows 2 --cols 1 > bin.step
const GRID_UNIT : Double = 42.0

///|
const WALL_THICKNESS : Double = 2.0

///|
const BASE_THICKNESS : Double = 2.0

///|
async fn main {
  let base_args_spec = {
    "rows": @cli.opt_double(
      1.0,
      help="Number of grid units in Y (rows)",
      min=1.0,
    ),
    "cols": @cli.opt_double(
      1.0,
      help="Number of grid units in X (cols)",
      min=1.0,
    ),
    "height": @cli.opt_double(
      30.0,
      help="Total bin height (mm)",
      min=BASE_THICKNESS + 1.0,
    ),
    "text": @cli.opt_string(short='t', help="Label text to engrave"),
    "fontSize": @cli.opt_double(
      0.0,
      help="Font size (mm), default is 60% of wall height",
      min=0.0,
    ),
    "depth": @cli.opt_double(
      0.5,
      help="Engraving depth (mm)",
      min=0.0,
      max=WALL_THICKNESS - 0.1,
    ),
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
      prog="05-gridfinity-compatible-bin",
      description="Generate a Gridfinity-compatible storage bin.",
    )
    is Some(args) else {
    return
  }
  let rows = args.double("rows").to_int()
  let cols = args.double("cols").to_int()
  let height = args.double("height")
  let text_opt = args.string_opt("text")
  let font_size_opt = args.double("fontSize")
  let emboss_depth = args.double("depth")
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
  let total_width = Double::from_int(cols) * GRID_UNIT
  let total_length = Double::from_int(rows) * GRID_UNIT
  let mut design = @cad.Design::new(name="gridfinity-bin")

  // 1. The Base
  let base = @cad.Cuboid::new(total_width, total_length, BASE_THICKNESS)
    .with_name("bin-base")
    .with_color(@cad.Rgb::red())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(base)

  // 2. Outer Walls
  let outer_poly = [
    (0.0, 0.0),
    (total_width, 0.0),
    (total_width, total_length),
    (0.0, total_length),
  ]
  let inner_poly = [
    (WALL_THICKNESS, WALL_THICKNESS),
    (total_width - WALL_THICKNESS, WALL_THICKNESS),
    (total_width - WALL_THICKNESS, total_length - WALL_THICKNESS),
    (WALL_THICKNESS, total_length - WALL_THICKNESS),
  ]
  let wall_height = height - BASE_THICKNESS
  let walls = @cad.ExtrudedProfile::new(outer_poly, wall_height, holes=[
      inner_poly,
    ])
    .with_name("bin-walls")
    .with_color(@cad.Rgb::cyan())
    .translate(x=tx, y=ty, z=tz + BASE_THICKNESS)
  design = design.add(walls)

  // 3. Internal Dividers
  for i in 1..<cols {
    let x = Double::from_int(i) * GRID_UNIT - WALL_THICKNESS / 2.0
    let div = @cad.Cuboid::new(
        WALL_THICKNESS,
        total_length - 2.0 * WALL_THICKNESS,
        wall_height,
      )
      .with_name("divider-x-\{i}")
      .with_color(@cad.Rgb::magenta())
      .translate(x=tx + x, y=ty + WALL_THICKNESS, z=tz + BASE_THICKNESS)
    design = design.add(div)
  }
  for j in 1..<rows {
    let y = Double::from_int(j) * GRID_UNIT - WALL_THICKNESS / 2.0
    let div = @cad.Cuboid::new(
        total_width - 2.0 * WALL_THICKNESS,
        WALL_THICKNESS,
        wall_height,
      )
      .with_name("divider-y-\{j}")
      .with_color(@cad.Rgb::green())
      .translate(x=tx + WALL_THICKNESS, y=ty + y, z=tz + BASE_THICKNESS)
    design = design.add(div)
  }

  // 4. Label Text
  match text_opt {
    Some(label) => {
      let font = @cad.load_font("baloo")
      if font_size_opt > 0.0 {
        design = design.add_text_on_face(
          walls,
          label,
          Back, // min_y face
          font,
          font_size=font_size_opt,
          emboss_depth~,
          color=@cad.Rgb::orange(),
        )
      } else {
        design = design.add_text_on_face(
          walls,
          label,
          Back, // min_y face
          font,
          emboss_depth~,
          color=@cad.Rgb::orange(),
        )
      }
    }
    None => ()
  }
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
