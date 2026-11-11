///|
/// components/examples/hardware_kit
///
/// Generate a screw + washer + nut hardware kit as either a flat STEP design or
/// a STEP assembly with separate products:
///
/// ```bash
/// moon run components/examples/hardware_kit -- \
///   --size M4 --length 20 --mode flat -o kit.step
/// ```
async fn main {
  let spec = {
    "size": @cli.opt_string(short='m', help="Metric size, e.g. M3, M4, M5"),
    "length": @cli.opt_double(
      20.0,
      short='l',
      help="Screw length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: simplified, detailed, full",
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/hardware_kit",
      description="Generate a metric fastener hardware kit.",
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
  let length = args.double("length")
  let detail = parse_detail(args.string_opt("detail").unwrap_or("simplified"))
  let assembly = match @assemblies.metric_hardware_kit(size, length, detail~) {
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
  let out_path = args.string_opt("out")
  let mode = args.string_opt("mode").unwrap_or("flat")
  match mode {
    "assembly" => assembly.write_assembly_step(out_path)
    "flat" => assembly.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "simplified" => @common.DetailLevel::Simplified
    "detailed" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fullymodeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}
