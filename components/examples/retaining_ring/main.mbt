///|
/// components/examples/retaining_ring
///
/// Generate a DIN 471 type A external retaining ring:
///
/// ```bash
/// moon run components/examples/retaining_ring -- --size 20 -o din471-20.step
/// moon run components/examples/retaining_ring -- --size 30 -o din471-30.step
/// ```
///
/// The free-state outline is the published reference model geometry. The
/// shaft groove is declared by a connector but is not modelled.
async fn main {
  let spec = {
    "size": @cli.opt_double(
      20.0,
      help="Nominal shaft diameter in mm (10 to 34, even sizes)",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/retaining_ring",
      description="Generate a DIN 471 type A external retaining ring.",
    )
    is Some(args) else {
    return
  }
  let component = match @fasteners.din471_ring(args.double("size")) {
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
