///|
/// components/examples/bearing
///
/// Generate a single radial ball bearing envelope:
///
/// ```bash
/// moon run --target native components/examples/bearing -- \
///   --bearing 608 --detail detailed -o bearing.step
/// ```
///
/// Rolling elements are analytic spheres; ring proportions, ball diameter, and
/// ring chamfers are parametric envelope geometry, not catalogue internals.
async fn main {
  let spec = {
    "bearing": @cli.opt_string(
      short='b',
      help="Bearing designation, e.g. 608, 6204",
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: simplified (default), detailed, full",
    ),
    "rollers": @cli.opt_int(
      8,
      short='r',
      help="Number of rolling elements",
      min=1,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bearing bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/bearing",
      description="Generate a single radial ball bearing envelope.",
    )
    is Some(args) else {
    return
  }
  let designation = args.string_opt("bearing").unwrap_or("608")
  let detail = parse_detail(args.string_opt("detail").unwrap_or("simplified"))
  let size = match @motion.bearing_size(designation) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let component = match
    @motion.bearing(size, roller_count=args.int("rollers"), detail~) {
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

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "detailed" | "detail" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fully_modeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}
