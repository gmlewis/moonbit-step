///|
/// components/examples/bolted_joint
///
/// Generate a through-bolted joint of two plates:
///
/// ```bash
/// moon run --target native components/examples/bolted_joint -- \
///   --size M4 --width 40 --depth 30 --thickness 5 -o joint.step
/// ```
async fn main {
  let spec = {
    "size": @cli.opt_string(short='m', help="Metric size, e.g. M4"),
    "width": @cli.opt_double(
      40.0,
      help="Plate width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "depth": @cli.opt_double(
      30.0,
      help="Plate depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      5.0,
      help="Plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: simplified, detailed, full",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/bolted_joint",
      description="Generate a through-bolted joint of two plates.",
    )
    is Some(args) else {
    return
  }
  let size_text = args.string_opt("size").unwrap_or("M4")
  let size = match @standards.MetricSize::parse(size_text) {
    Some(s) => s
    None => {
      @cli.eprintln("error: unsupported metric size: " + size_text)
      abort("")
    }
  }
  let detail = parse_detail(args.string_opt("detail").unwrap_or("detailed"))
  let assembly = match
    @assemblies.bolted_joint(
      size,
      args.double("width"),
      args.double("depth"),
      args.double("thickness"),
      detail~,
    ) {
    Ok(a) => a
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  assembly.write_step(args.string_opt("out"), checked=true)
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "simplified" => @common.DetailLevel::Simplified
    "detailed" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" => @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Detailed
  }
}
