///|
/// components/examples/stock_primitive
///
/// Generate a steel angle section or a flat plate blank:
///
/// ```bash
/// moon run components/examples/stock_primitive -- \
///   --part angle --legA 40 --legB 40 --thickness 4 --length 50 -o angle.step
/// moon run components/examples/stock_primitive -- \
///   --part plate --width 50 --height 50 --plateThickness 3 -o plate.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(short='p', help="Part: angle (default) or plate"),
    "legA": @cli.opt_double(40.0, help="Angle leg A in mm", min=0.0),
    "legB": @cli.opt_double(40.0, help="Angle leg B in mm", min=0.0),
    "thickness": @cli.opt_double(4.0, help="Angle leg thickness in mm", min=0.0),
    "rootRadius": @cli.opt_double(
      6.0,
      help="Angle root fillet radius in mm",
      min=0.0,
    ),
    "toeRadius": @cli.opt_double(3.0, help="Angle toe radius in mm", min=0.0),
    "length": @cli.opt_double(50.0, help="Angle bar length in mm", min=0.0),
    "width": @cli.opt_double(50.0, help="Plate width in mm", min=0.0),
    "height": @cli.opt_double(50.0, help="Plate height in mm", min=0.0),
    "plateThickness": @cli.opt_double(
      3.0,
      help="Plate thickness in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/stock_primitive",
      description="Generate an angle section or a plate blank.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("angle")
  let component = match part_kind {
    "plate" =>
      match
        @stock.plate(
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    _ => {
      let section = match
        @stock.angle_section(
          leg_a_mm=args.double("legA"),
          leg_b_mm=args.double("legB"),
          thickness_mm=args.double("thickness"),
          root_radius_mm=args.double("rootRadius"),
          toe_radius_mm=args.double("toeRadius"),
        ) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match @stock.angle_bar(section, args.double("length")) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
