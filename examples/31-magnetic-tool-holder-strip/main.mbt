///|
/// 31-magnetic-tool-holder-strip
///
/// A strip with magnet pockets, spacing rules, and configurable retention lips.
///
/// Usage (stdout):
///   moon run --target native examples/31-magnetic-tool-holder-strip -- --rows 1 --cols 5 > strip.step
///
/// Usage (write file):
///   moon run --target native examples/31-magnetic-tool-holder-strip -- -o strip.step --rows 2 --cols 3
async fn main {
  let base_args_spec = {
    "rows": @cli.opt_int(1, help="Number of rows", min=1),
    "cols": @cli.opt_int(5, help="Number of columns", min=1),
    "cellSize": @cli.opt_double(30.0, help="Size of each cell (mm)", min=10.0),
    "magnetDiameter": @cli.opt_double(
      10.0,
      help="Diameter of magnet (mm)",
      min=1.0,
    ),
    "magnetDepth": @cli.opt_double(
      3.0,
      help="Depth of magnet pocket (mm)",
      min=0.1,
    ),
    "lipThickness": @cli.opt_double(
      0.5,
      help="Thickness of retention lip (mm)",
      min=0.0,
    ),
    "lipWidth": @cli.opt_double(
      1.0,
      help="Width of retention lip (mm)",
      min=0.0,
    ),
    "thickness": @cli.opt_double(
      6.0,
      help="Total thickness of the strip (mm)",
      min=5.0,
    ),
    "filletRadius": @cli.opt_double(
      3.0,
      help="Fillet radius for the strip corners (mm)",
      min=0.0,
    ),
    "labelPrefix": @cli.opt_string(help="Prefix for pocket labels"),
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
      prog="31-magnetic-tool-holder-strip",
      description="Generate a magnetic tool holder strip.",
    )
    is Some(args) else {
    return
  }
  let rows = args.int("rows")
  let cols = args.int("cols")
  let cell_size = args.double("cellSize")
  let magnet_diameter = args.double("magnetDiameter")
  let magnet_depth = args.double("magnetDepth")
  let lip_thickness = args.double("lipThickness")
  let lip_width = args.double("lipWidth")
  let thickness = args.double("thickness")
  let fillet_radius = args.double("filletRadius")
  let label_prefix = args.string_opt("labelPrefix")
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
  if magnet_depth >= thickness {
    @cli.eprintln("error: magnetDepth must be less than thickness")
    return
  }
  if lip_thickness >= magnet_depth {
    @cli.eprintln("error: lipThickness must be less than magnetDepth")
    return
  }
  let total_width = Double::from_int(cols) * cell_size
  let total_height = Double::from_int(rows) * cell_size
  let mut design = @cad.Design::new(name="magnetic-tool-strip")

  // Generate magnet locations
  let centers = []
  for r in 0..<rows {
    for c in 0..<cols {
      let x = (Double::from_int(c) + 0.5) * cell_size
      let y = (Double::from_int(r) + 0.5) * cell_size
      centers.push((x, y))
    }
  }

  // 1. Bottom solid layer
  let bottom_height = thickness - magnet_depth
  let outer_profile = @cad.Profile2D::rounded_rect(
    total_width, total_height, fillet_radius,
  )
  let bottom_part = @cad.ExtrudedProfile::new(outer_profile, bottom_height)
    .with_name("strip-bottom")
    .with_color(@cad.Rgb::purple())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(bottom_part)

  // 2. Middle pocket layer (main magnet cavity)
  let middle_height = magnet_depth - lip_thickness
  let magnet_profile = @cad.Profile2D::circle(magnet_diameter)
  let middle_part_profile = @cad.Profile2D::new(outer_profile).add_holes_at(
    centers, magnet_profile,
  )
  let middle_part = @cad.ExtrudedProfile::new(
      middle_part_profile.outer,
      middle_height,
      holes=middle_part_profile.holes,
    )
    .with_name("strip-middle")
    .with_color(@cad.Rgb::cyan())
    .translate(x=tx, y=ty, z=tz + bottom_height)
  design = design.add(middle_part)

  // 3. Top lip layer
  if lip_thickness > 0.0 {
    let lip_diameter = magnet_diameter - 2.0 * lip_width
    let lip_profile = @cad.Profile2D::circle(lip_diameter)
    let top_part_profile = @cad.Profile2D::new(outer_profile).add_holes_at(
      centers, lip_profile,
    )
    let top_part = @cad.ExtrudedProfile::new(
        top_part_profile.outer,
        lip_thickness,
        holes=top_part_profile.holes,
      )
      .with_name("strip-top")
      .with_color(@cad.Rgb::magenta())
      .translate(x=tx, y=ty, z=tz + bottom_height + middle_height)
    design = design.add(top_part)
  }

  // 4. Optional labels for each pocket
  match label_prefix {
    Some(prefix) => {
      let font = @cad.load_font("baloo")
      let bbox_node = @cad.Cuboid::new(total_width, total_height, thickness)
        .with_name("bbox")
        .translate(x=tx, y=ty, z=tz)
      for r in 0..<rows {
        for c in 0..<cols {
          let label = "\{prefix}-\{r + 1}-\{c + 1}"
          let x = (Double::from_int(c) + 0.5) * cell_size
          let y = (Double::from_int(r) + 0.5) * cell_size
          // Put label on the top face
          design = design.add_text_on_face(
            bbox_node,
            label,
            Top,
            font,
            font_size=magnet_diameter * 0.35,
            offset_x=x - total_width / 2.0,
            offset_y=y - total_height / 2.0 + magnet_diameter * 0.75,
            emboss_depth=0.2,
            color=@cad.Rgb::orange(),
          )
        }
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
