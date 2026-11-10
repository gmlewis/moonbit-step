///|
/// components/examples/filleted_shaft
///
/// Generate a stepped shaft with toroidal shoulder fillets:
///
/// ```bash
/// moon run --target native components/examples/filleted_shaft -- \
///   --fillet 2 -o filleted-shaft.step
/// ```
///
/// The fillet is a real `TOROIDAL_SURFACE` of revolution, not a chamfer.
async fn main {
  let spec = {
    "fillet": @cli.opt_double(
      2.0,
      short='f',
      help="Shoulder fillet radius in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/filleted_shaft",
      description="Generate a stepped shaft with shoulder fillets.",
    )
    is Some(args) else {
    return
  }
  let segments : Array[(Double, Double)] = [(10.0, 20.0), (16.0, 15.0)]
  let fillet = args.double("fillet")
  let component = match
    @motion.filleted_stepped_shaft(segments, fillet_radius_mm=fillet) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  component.write_step(args.string_opt("out"), checked=true)
  @cli.eprintln("wrote filleted stepped shaft")
}
