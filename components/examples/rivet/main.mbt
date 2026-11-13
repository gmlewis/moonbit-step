///|
/// components/examples/rivet
///
/// Generate a generic solid rivet:
///
/// ```bash
/// moon run components/examples/rivet -- --shank 3 --length 10 -o rivet.step
/// moon run components/examples/rivet -- \
///   --shank 4 --length 12 --headDiameter 8 --headHeight 2 -o rivet.step
/// ```
///
/// The rivet is a generic parametric form, not a standard part.
async fn main {
  let spec = {
    "shank": @cli.opt_double(3.0, help="Shank diameter in mm", min=0.0),
    "length": @cli.opt_double(10.0, help="Overall rivet length in mm", min=0.0),
    "headDiameter": @cli.opt_double(
      0.0,
      help="Head diameter in mm (0 = 1.8 x shank)",
      min=0.0,
    ),
    "headHeight": @cli.opt_double(
      0.0,
      help="Head height in mm (0 = 0.35 x shank)",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/rivet",
      description="Generate a generic solid rivet.",
    )
    is Some(args) else {
    return
  }
  let component = match
    @fasteners.solid_rivet(
      args.double("shank"),
      args.double("length"),
      head_diameter_mm=args.double("headDiameter"),
      head_height_mm=args.double("headHeight"),
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
