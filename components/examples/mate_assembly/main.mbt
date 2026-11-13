///|
/// components/examples/mate_assembly
///
/// Place an ISO 4762 socket head cap screw in an ISO 4032 nut by named mate
/// connectors and write the resulting assembly to STEP:
///
/// ```bash
/// moon run components/examples/mate_assembly -- --size M4 --length 20 -o mate.step
/// ```
async fn main {
  let spec = {
    "size": @cli.opt_string(help="Metric size: M3, M4, or M5 (default M4)"),
    "length": @cli.opt_double(
      20.0,
      short='l',
      help="Screw length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mate_assembly",
      description="Mate a socket head cap screw into a hex nut by connector names.",
    )
    is Some(args) else {
    return
  }
  let size = match args.string_opt("size").unwrap_or("M4") {
    "M3" => @standards.MetricSize::M3
    "M4" => @standards.MetricSize::M4
    "M5" => @standards.MetricSize::M5
    other => {
      @cli.eprintln("error: unsupported size '\{other}'; use M3, M4, or M5")
      abort("")
    }
  }
  let length = args.double("length")
  let nut = match @fasteners.iso4032_nut(size) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let screw = match @fasteners.iso4762_screw(size, length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pair = @common.MatePair::new(
    parent="bore",
    child="shaft",
    description="screw shank into nut bore",
  )
  let assembly = @assemblies.Assembly::new(name="screw-and-nut").add(
    nut,
    instance_name="nut",
  )
  let (placed, alignment) = match
    assembly.add_mate_pair("nut", screw, pair, instance_name="screw") {
    Ok(result) => result
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let (x, y, z) = alignment.placement.trans
  let (ax, ay, az) = alignment.axis
  println(
    "placed \{placed.count()} instances; screw origin at (\{x}, \{y}, \{z}) mm",
  )
  println(
    "joint axis (child frame): (\{ax}, \{ay}, \{az}); anti-parallel interface: \{alignment.insertion_anti_parallel}",
  )
  placed.write_step(args.string_opt("out"), checked=true)
}
