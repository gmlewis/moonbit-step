///|
/// components/examples/mot_edis
///
/// Generate a MotEDis 40 x 40 I-type slot-8 metric T-slot extrusion:
///
/// ```bash
/// moon run components/examples/mot_edis -- --length 500 -o motedis-500.step
/// ```
///
/// The four T-slots are a nominal difference: the flat STEP concatenates the
/// cutter faces (the file is marked nominal) and the CAD kernel trims them.
async fn main {
  let spec = {
    "length": @cli.opt_double(
      100.0,
      short='l',
      help="Extrusion length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mot_edis",
      description="Generate a MotEDis 40 x 40 I-type slot-8 T-slot extrusion.",
    )
    is Some(args) else {
    return
  }
  let component = match
    @profiles.mot_edis_profile(length_mm=args.double("length")) {
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
