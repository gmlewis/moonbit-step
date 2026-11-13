///|
/// components/examples/linear_bearing
///
/// Generate an LM-series linear bushing envelope or a flanged housing:
///
/// ```bash
/// moon run components/examples/linear_bearing -- \
///   --bearing LM8UU -o lm8uu.step
/// moon run components/examples/linear_bearing -- \
///   --bearing LM8UU --flanged --orient-to-reference -o fl8uu.step
/// ```
async fn main {
  let spec = {
    "bearing": @cli.opt_string(
      short='b',
      help="LM-series designation: LM6UU, LM8UU, LM10UU, LM12UU, LM16UU, LM20UU",
    ),
    "flanged": @cli.flag(help="Build the flanged round housing instead"),
    "flangeDiameter": @cli.opt_double(
      0.0,
      help="Flange diameter in mm (0 = scaled default)",
      min=0.0,
    ),
    "flangeThickness": @cli.opt_double(
      0.0,
      help="Flange thickness in mm (0 = scaled default)",
      min=0.0,
    ),
    "orient-to-reference": @cli.flag(
      help="Match the golden reference frame (axis X, centered)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/linear_bearing",
      description="Generate an LM-series linear bushing envelope.",
    )
    is Some(args) else {
    return
  }
  let designation = args.string_opt("bearing").unwrap_or("LM8UU")
  let size = match @motion.linear_bearing_size(designation) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let oriented = args.flag("orient-to-reference")
  let part = if args.flag("flanged") {
    let flange_diameter = if args.double("flangeDiameter") > 0.0 {
      args.double("flangeDiameter")
    } else {
      1.65 * size.outer_mm
    }
    let flange_thickness = if args.double("flangeThickness") > 0.0 {
      args.double("flangeThickness")
    } else {
      0.1125 * size.length_mm
    }
    match
      @motion.flanged_linear_bearing(
        size,
        flange_diameter_mm=flange_diameter,
        flange_thickness_mm=flange_thickness,
        orient_to_reference=oriented,
      ) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
  } else {
    match @motion.linear_bearing(size, orient_to_reference=oriented) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  part.write_step(args.string_opt("out"), checked=true)
}
