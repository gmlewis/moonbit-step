///|
/// 39-analytic-cylinders-and-fits
///
/// A small gauge that demonstrates two kinds of modeling intent:
///
/// - `Cylinder::new` emits analytic cylinders (one `CYLINDRICAL_SURFACE` and
///   two circular caps) instead of a faceted 64-gon.
/// - `Profile2D::hole_with_fit` applies a per-face clearance, so one nominal
///   diameter produces Nominal, Close, Free, and Press holes.
///
/// Four pegs of the nominal diameter sit in front of the plate, one per fit.
/// Export goes through the checked entry point.
///
/// Usage:
///   ./examples/run-example.sh 39 -o fits.step
///   ./examples/run-example.sh 39 --diameter 8 --spacing 16
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(
      10.0,
      short='d',
      help="Nominal hole and pin diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      5.0,
      help="Plate thickness (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "pinHeight": @cli.opt_double(
      8.0,
      help="Pin height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "spacing": @cli.opt_double(
      20.0,
      help="Hole spacing (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write STEP output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="39-analytic-cylinders-and-fits",
      description="Generate an analytic cylinder and fit-clearance gauge.",
    )
    is Some(args) else {
    return
  }
  let diameter = args.double("diameter")
  let thickness = args.double("thickness")
  let pin_height = args.double("pinHeight")
  let spacing = args.double("spacing")
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
  let fits : Array[(@cad.Fit, String, @cad.Rgb)] = [
    (Nominal, "nominal", @cad.Rgb::grey()),
    (Close, "close", @cad.Rgb::blue()),
    (Free, "free", @cad.Rgb::green()),
    (Press, "press", @cad.Rgb::red()),
  ]

  // Plate with one fitted hole per clearance preset.
  let count = fits.length()
  let plate_width = spacing * Double::from_int(count)
  let plate_depth = 2.0 * spacing
  let holes : Array[Array[@cad.Vec2]] = []
  for i, entry in fits {
    let x = spacing * (Double::from_int(i) + 0.5)
    let y = plate_depth / 2.0
    holes.push(
      @cad.translate_pts(
        @cad.Profile2D::hole_with_fit(diameter, fit=entry.0),
        x,
        y,
      ),
    )
  }
  let mut design = @cad.Design::new(
    name="analytic-fits",
    documentation=args.documentation(),
  ).add(
    @cad.ExtrudedProfile::new(
      @cad.Profile2D::rect(plate_width, plate_depth),
      thickness,
      holes~,
    )
    .with_name("fit-plate")
    .with_color(@cad.Rgb::orange()),
  )

  // One analytic cylinder peg per fit, in front of the plate.
  for i, entry in fits {
    let x = spacing * (Double::from_int(i) + 0.5)
    design = design.add(
      @cad.Cylinder::new(diameter, pin_height)
      .with_name("pin-\{entry.1}")
      .with_color(entry.2)
      .translate(x~, y=-spacing, z=0.0),
    )
  }
  let design = design.translate(x=tx, y=ty, z=tz)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path, checked=true)
  }
}
