///|
/// components/examples/spring
///
/// Generate a simplified helical compression spring. The default uses smooth
/// B-spline side surfaces and a 36-segment wire so the axial and radial
/// directions are not faceted; pass `--detailed` for the 12-gon faceted sweep.
///
/// ```bash
/// moon run components/examples/spring -- \
///   --meanDiameter 10 --wireDiameter 1 --length 20 --coils 8 -o spring.step
/// ```
async fn main {
  let spec = {
    "meanDiameter": @cli.opt_double(
      10.0,
      short='D',
      help="Mean coil diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "wireDiameter": @cli.opt_double(
      1.0,
      short='d',
      help="Wire diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "length": @cli.opt_double(
      20.0,
      short='l',
      help="Free length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coils": @cli.opt_int(8, short='n', help="Active coil count"),
    "segments": @cli.opt_int(24, short='s', help="Segments per coil"),
    "detailed": @cli.flag(
      help="Use the faceted 12-gon sweep instead of the smooth B-spline sides",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/spring",
      description="Generate a simplified compression spring.",
    )
    is Some(args) else {
    return
  }
  let detailed = args.flag("detailed")
  let spring = match
    @motion.compression_spring(
      args.double("meanDiameter"),
      args.double("wireDiameter"),
      args.double("length"),
      args.int("coils"),
      segments_per_turn=args.int("segments"),
      wire_segments=if detailed { 12 } else { 36 },
      smooth=!detailed,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  spring.write_step(args.string_opt("out"), checked=true)
}
