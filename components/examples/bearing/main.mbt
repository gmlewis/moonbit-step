///|
/// components/examples/bearing
///
/// Generate a radial ball bearing. The default is a physically plausible
/// full-complement deep-groove bearing: grooved rings with retaining
/// shoulders and a full ring of balls. `--representation envelope` reproduces
/// the thin ring/ball envelope used by the golden references.
///
/// ```bash
/// moon run components/examples/bearing -- \
///   --bearing 608 --detail detailed -o bearing.step
/// ```
///
/// Ball size, count, raceway conformity, and shoulder retention are
/// engineering defaults, not catalogue internals. Use `--shielded` for the
/// single-solid shielded envelope.
async fn main {
  let spec = {
    "bearing": @cli.opt_string(
      short='b',
      help="Bearing designation, e.g. 608, 6204",
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: detailed (default), simplified, full",
    ),
    "representation": @cli.opt_string(
      help="Representation: deep-groove (default, full complement with grooved rings) or envelope",
    ),
    "rollers": @cli.opt_int(
      0,
      short='r',
      help="Number of balls (0 = full complement for deep-groove, rings only for envelope)",
      min=0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "shielded": @cli.flag(
      help="Single-solid shielded envelope: recessed face shield grooves, no rolling elements",
    ),
    "bbox": @cli.flag(help="Print the bearing bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/bearing",
      description="Generate a radial ball bearing with grooved rings and a full ball complement (or the golden envelope).",
    )
    is Some(args) else {
    return
  }
  let designation = args.string_opt("bearing").unwrap_or("608")
  let detail = parse_detail(args.string_opt("detail").unwrap_or("detailed"))
  let representation = args
    .string_opt("representation")
    .unwrap_or("deep-groove")
  if representation != "deep-groove" && representation != "envelope" {
    @cli.eprintln(
      "error: unknown representation: " +
      representation +
      " (expected deep-groove or envelope)",
    )
    abort("")
  }
  let size = match @motion.bearing_size(designation) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let component = if args.flag("shielded") {
    match @motion.shielded_bearing(size, detail~) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
  } else if representation == "envelope" {
    match @motion.bearing(size, roller_count=args.int("rollers"), detail~) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
  } else {
    match
      @motion.deep_groove_bearing(size, ball_count=args.int("rollers"), detail~) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
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
