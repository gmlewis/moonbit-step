///|
/// 32-spool-holder-bracket
///
/// A bracket that adapts to multiple spool widths and axle diameters.
///
/// Usage (stdout):
///   moon run --target native examples/32-spool-holder-bracket -- > bracket.step
///
/// Usage (write file):
///   moon run --target native examples/32-spool-holder-bracket -- -o bracket.step
async fn main {
  let base_args_spec = {
    "baseLength": @cli.opt_double(
      80.0,
      help="Base plate length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "baseThickness": @cli.opt_double(
      10.0,
      help="Base plate thickness (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "armHeight": @cli.opt_double(
      120.0,
      help="Arm height from base (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "armWidth": @cli.opt_double(
      30.0,
      help="Arm width / extrusion depth (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "armBaseThickness": @cli.opt_double(
      40.0,
      help="Arm thickness at base (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "armTopThickness": @cli.opt_double(
      25.0,
      help="Arm thickness at top (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "axleDia": @cli.opt_double(
      20.0,
      help="Axle diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "holeDia": @cli.opt_double(
      6.0,
      help="Mounting hole diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "holeSpacing": @cli.opt_double(
      60.0,
      help="Mounting hole spacing (mm)",
      min=0.0,
      min_exclusive=true,
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
      prog="32-spool-holder-bracket",
      description="Generate a spool holder bracket STEP model.",
    )
    is Some(args) else {
    return
  }
  let base_length = args.double("baseLength")
  let base_thickness = args.double("baseThickness")
  let arm_height = args.double("armHeight")
  let arm_width = args.double("armWidth")
  let arm_base_thickness = args.double("armBaseThickness")
  let arm_top_thickness = args.double("armTopThickness")
  let axle_dia = args.double("axleDia")
  let hole_dia = args.double("holeDia")
  let hole_spacing = args.double("holeSpacing")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Validate parameters
  if arm_top_thickness < axle_dia {
    @cli.eprintln("error: armTopThickness must be >= axleDia")
    abort("")
  }
  if hole_spacing >= base_length {
    @cli.eprintln("error: holeSpacing must be < baseLength")
    abort("")
  }
  if arm_base_thickness >= hole_spacing - hole_dia {
    @cli.eprintln(
      "error: armBaseThickness must be < holeSpacing - holeDia to avoid blocking holes",
    )
    abort("")
  }

  // 1. Base (Top view extrusion)
  let base_outer = @cad.Profile2D::centered_rect(base_length, arm_width)
  let hole_profile = @cad.Profile2D::circle(hole_dia).rev()
  let base_holes = [
    @cad.translate_pts(hole_profile, -hole_spacing / 2.0, 0.0),
    @cad.translate_pts(hole_profile, hole_spacing / 2.0, 0.0),
  ]
  let base = @cad.ExtrudedProfile::new(
      base_outer,
      base_thickness,
      holes=base_holes,
    )
    .with_name("base")
    .with_color(@cad.Rgb::new(0.2, 0.4, 0.8)) // Beautiful blue
    .translate(x=tx, y=ty, z=tz)

  // 2. Arm (Side view extrusion)
  let arm_z0 = base_thickness
  let arm_z1 = base_thickness + arm_height
  let arm_pts = []
  arm_pts.push((-arm_base_thickness / 2.0, arm_z0))
  arm_pts.push((arm_base_thickness / 2.0, arm_z0))
  arm_pts.push((arm_top_thickness / 2.0, arm_z1))

  // Add cradle arc (concave)
  // arc(dia, PI, 2*PI).rev() goes from (R, 0) to (-R, 0) through (0, -R)
  let arc_pts = @cad.Profile2D::arc(axle_dia, @math.PI, 2.0 * @math.PI).rev()
  for pt in arc_pts {
    arm_pts.push((pt.0, pt.1 + arm_z1))
  }
  arm_pts.push((-arm_top_thickness / 2.0, arm_z1))
  let arm = @cad.ExtrudedProfile::new(arm_pts, arm_width)
    .with_name("arm")
    .with_color(@cad.Rgb::new(0.2, 0.8, 0.8)) // Beautiful cyan
    .rotate_x(90.0)
    .translate(x=tx, y=ty + arm_width / 2.0, z=tz) // center it on base
  let design = @cad.Design::new(name="spool-holder-bracket").add(base).add(arm)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
