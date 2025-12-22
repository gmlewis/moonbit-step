///|
// 05-gridfinity-compatible-bin
//
// A maker-friendly storage bin generator.
//
// Usage (stdout):
//   moon run --target native examples/05-gridfinity-compatible-bin -- --rows 2 --cols 1 > bin.step
//

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
    "embossDepth": @cli.opt_double(
      0.5,
      help="Engraving depth (mm)",
      min=0.0,
      max=WALL_THICKNESS - 0.1,
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
  let font_size = args.double("fontSize")
  let emboss_depth = args.double("embossDepth")
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

  // 2. Outer Walls (Extruded Profile with a hole)
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
    .with_color(@cad.Rgb::new(0.0, 1.0, 1.0)) // cyan
    .translate(x=tx, y=ty, z=tz + BASE_THICKNESS)
  design = design.add(walls)

  // 3. Internal Dividers (if cols > 1 or rows > 1)
  // X Dividers
  for i in 1..<cols {
    let x = Double::from_int(i) * GRID_UNIT - WALL_THICKNESS / 2.0
    let div = @cad.Cuboid::new(
        WALL_THICKNESS,
        total_length - 2.0 * WALL_THICKNESS,
        wall_height,
      )
      .with_name("divider-x-\{i}")
      .with_color(@cad.Rgb::new(1.0, 0.0, 1.0)) // magenta
      .translate(x=tx + x, y=ty + WALL_THICKNESS, z=tz + BASE_THICKNESS)
    design = design.add(div)
  }
  // Y Dividers
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

  // 4. Label Text (if provided)
  match text_opt {
    Some(label) => {
      let margin = WALL_THICKNESS + 2.0
      let label_width = total_width - 2.0 * margin
      if label_width > 5.0 {
        let label_height = if font_size > 0.0 {
          font_size
        } else {
          wall_height * 0.6
        }
        let bbox = @draw.bbox(0.0, 0.0, label_width, label_height)
        let font = @baloo.font
        let text_fitted = @draw.to_graphic(
          font,
          label,
          alignment=Center,
          y_up=true,
        ).scale_to_fit(bbox, anchor=Center) catch {
          e => {
            @cli.eprintln("Error creating text: \{e}")
            abort("")
          }
        }
        let all_paths = text_fitted.all_paths_and_compound_paths()
        for g in all_paths {
          let profiles = @draw.Graphic::to_profiles_tuples(g, 8)
          for profile in profiles {
            let (outer, holes) = profile
            if outer.length() < 3 {
              continue
            }
            // Engrave on the front wall (-Y face)
            // We extend the extrusion slightly (0.1mm) outside the face
            // to avoid Z-fighting and ensure clean boolean operations.
            let text_solid = @cad.ExtrudedProfile::new(
                outer,
                emboss_depth + 0.1,
                holes~,
              )
              .with_name("label")
              .with_color(@cad.Rgb::orange())
              .rotate_x(90.0)
              .translate(
                x=tx + margin,
                y=ty + emboss_depth,
                z=tz + BASE_THICKNESS + (wall_height - label_height) / 2.0,
              )
            design = design.add(text_solid)
          }
        }
      }
    }
    None => ()
  }
  design.write_step(out_path)
}
