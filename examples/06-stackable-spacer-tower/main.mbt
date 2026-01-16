///|
/// 06-stackable-spacer-tower
///
/// A set of stackable spacers with interlocking features.
///
/// Usage (stdout):
///   moon run --target native examples/06-stackable-spacer-tower -- --count 3 > tower.step
async fn main {
  let base_args_spec = {
    "count": @cli.opt_double(
      1.0,
      help="Number of spacers in the tower",
      min=1.0,
    ),
    "id": @cli.opt_double(10.0, help="Inner diameter of the hole (mm)", min=1.0),
    "mid": @cli.opt_double(
      15.0,
      help="Diameter of the interlocking feature (mm)",
      min=2.0,
    ),
    "od": @cli.opt_double(
      25.0,
      help="Outer diameter of the spacer (mm)",
      min=3.0,
    ),
    "height": @cli.opt_double(
      5.0,
      help="Height of the spacer body (mm)",
      min=1.0,
    ),
    "clickHeight": @cli.opt_double(
      2.0,
      help="Height of the interlocking protrusion (mm)",
      min=0.5,
    ),
    "resolution": @cli.opt_double(64.0, help="Circle segments", min=3.0),
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
      prog="06-stackable-spacer-tower",
      description="Generate a stackable spacer tower.",
    )
    is Some(args) else {
    return
  }
  let count = args.double("count").to_int()
  let id = args.double("id")
  let mid = args.double("mid")
  let od = args.double("od")
  let height = args.double("height")
  let click_height = args.double("clickHeight")
  let resolution = args.double("resolution").to_int()
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }

  // Basic validation
  if id >= mid {
    @cli.eprintln(
      "error: inner diameter (\{id}) must be less than middle diameter (\{mid})",
    )
    abort("")
  }
  if mid >= od {
    @cli.eprintln(
      "error: middle diameter (\{mid}) must be less than outer diameter (\{od})",
    )
    abort("")
  }
  let mut design = @cad.Design::new(name="spacer-tower")

  // Generate profiles
  let outer_circle = @cad.Profile2D::circle(od, segments=resolution)
  let mid_circle = @cad.Profile2D::circle(mid, segments=resolution)
  let inner_circle = @cad.Profile2D::circle(id, segments=resolution)
  let colors = [@cad.Rgb::orange(), @cad.Rgb::green(), @cad.Rgb::blue()]
  for i in 0..<count {
    let base_z = tz + Double::from_int(i) * (height + click_height)
    let color = colors[i % 3]

    // 1. Spacer Body (Ring from od to mid)
    let body = @cad.ExtrudedProfile::new(outer_circle, height, holes=[
        mid_circle,
      ])
      .with_name("spacer-body-\{i}")
      .with_color(color)
      .translate(x=tx, y=ty, z=base_z)
    design = design.add(body)

    // 2. Interlocking Protrusion (Ring from mid to id)
    // It sits on top of the body.
    let protrusion = @cad.ExtrudedProfile::new(mid_circle, click_height, holes=[
        inner_circle,
      ])
      .with_name("spacer-click-\{i}")
      .with_color(color)
      .translate(x=tx, y=ty, z=base_z + height)
    design = design.add(protrusion)
  }
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
