///|
/// components/examples/mot_edis
///
/// Generate a MotEDis I-type metric T-slot extrusion or T-nut:
///
/// ```bash
/// moon run components/examples/mot_edis -- --series 40 --length 500 -o m40.step
/// moon run components/examples/mot_edis -- --series 20 --length 250 -o m20.step
/// moon run components/examples/mot_edis -- \
///   --part tnut --series 40 --thread M5 -o tnut-m5.step
/// ```
///
/// The profile's four T-slots are a nominal difference: the flat STEP
/// concatenates the cutter faces (the file is marked nominal) and the CAD
/// kernel trims them.
async fn main {
  let spec = {
    "part": @cli.opt_string(short='p', help="Part: profile (default) or tnut"),
    "series": @cli.opt_string(short='s', help="I-type series: 20, 30, or 40"),
    "length": @cli.opt_double(
      100.0,
      short='l',
      help="Extrusion length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thread": @cli.opt_string(short='t', help="T-nut thread (e.g. M5)"),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mot_edis",
      description="Generate a MotEDis I-type metric T-slot extrusion or T-nut.",
    )
    is Some(args) else {
    return
  }
  let series = args.string_opt("series").unwrap_or("40")
  let section = match @profiles.mot_edis_section(series) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let part_kind = args.string_opt("part").unwrap_or("profile")
  let component = match part_kind {
    "profile" =>
      match
        @profiles.mot_edis_profile_of(section, length_mm=args.double("length")) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "tnut" =>
      match
        @profiles.mot_edis_tnut(
          section,
          thread=args.string_opt("thread").unwrap_or("M5"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    other => {
      @cli.eprintln("error: unknown part: " + other)
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
