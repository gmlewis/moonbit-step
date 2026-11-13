///|
/// components/examples/din472_ring
///
/// Generate a DIN 472 internal retaining ring:
///
/// ```bash
/// moon run components/examples/din472_ring -- --size 20 -o din472-20.step
/// moon run components/examples/din472_ring -- --size 20 --goldenFrame -o ring-golden.step
/// ```
///
/// `--goldenFrame` is a comparison-only option: it maps the ring into the
/// published golden reference frame (ring in XY, z = 0..s, lugs toward -Y)
/// without changing the builder's default XY-plane, z = 0..s, lugs +X frame.
/// The free-state outline is the CC0 Innerscene 20 mm reference geometry. The
/// bore groove is declared by a connector but is not modelled.
async fn main {
  let spec = {
    "size": @cli.opt_double(
      20.0,
      help="Nominal bore diameter in mm (only 20 has an encoded outline)",
      min=0.0,
    ),
    "goldenFrame": @cli.flag(
      help="Emit the ring in the published golden reference frame (XY plane, lugs -Y; comparison only)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/din472_ring",
      description="Generate a DIN 472 internal retaining ring.",
    )
    is Some(args) else {
    return
  }
  let mut component = match @fasteners.din472_ring(args.double("size")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("goldenFrame") {
    // The CC0 Innerscene DIN 472 20 mm reference writes the ring in the XY
    // plane with the lugs toward -Y. Keep the library's default XY-plane,
    // z = 0..s, lugs +X frame and map only the golden output.
    component = component.rotate_z(-90.0)
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
