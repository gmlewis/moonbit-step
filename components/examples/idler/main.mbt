///|
/// components/examples/idler
///
/// Generate a smooth (toothless) idler with optional end flanges:
///
/// ```bash
/// moon run components/examples/idler -- --outer 20 --bore 8 --width 10 -o idler.step
/// moon run components/examples/idler -- \
///   --outer 20 --bore 8 --width 10 --flangeDiameter 24 --flangeThickness 1.5 -o idler.step
/// ```
async fn main {
  let spec = {
    "outer": @cli.opt_double(20.0, help="Hub outside diameter in mm", min=0.0),
    "bore": @cli.opt_double(8.0, help="Through bore in mm", min=0.0),
    "width": @cli.opt_double(10.0, help="Hub width in mm", min=0.0),
    "flangeDiameter": @cli.opt_double(
      0.0,
      help="Flange outside diameter in mm (0 = no flange)",
      min=0.0,
    ),
    "flangeThickness": @cli.opt_double(
      0.0,
      help="Flange thickness in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/idler",
      description="Generate a smooth idler with optional end flanges.",
    )
    is Some(args) else {
    return
  }
  let component = match
    @motion.smooth_idler(
      args.double("outer"),
      args.double("bore"),
      args.double("width"),
      flange_diameter_mm=args.double("flangeDiameter"),
      flange_thickness_mm=args.double("flangeThickness"),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
