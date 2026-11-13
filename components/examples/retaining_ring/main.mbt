///|
/// components/examples/retaining_ring
///
/// Generate a DIN 471 type A external retaining ring:
///
/// ```bash
/// moon run components/examples/retaining_ring -- --size 20 -o din471-20.step
/// moon run components/examples/retaining_ring -- --size 30 -o din471-30.step
/// moon run components/examples/retaining_ring -- --size 20 --goldenFrame -o ring-golden.step
/// ```
///
/// `--goldenFrame` is a comparison-only option: it maps the ring into the
/// published golden reference frame (ring in YZ, lugs toward +Y, near face at
/// x = s/2) without changing the builder's default XY-plane, z = 0..s frame.
/// The free-state outline is the published reference model geometry. The
/// shaft groove is declared by a connector but is not modelled.
async fn main {
  let spec = {
    "size": @cli.opt_double(
      20.0,
      help="Nominal shaft diameter in mm (10 to 34, even sizes)",
      min=0.0,
    ),
    "goldenFrame": @cli.flag(
      help="Emit the ring in the published golden reference frame (ring in YZ, lugs +Y; comparison only)",
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
  let mut component = match @fasteners.din471_ring(args.double("size")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("goldenFrame") {
    // The FreeCAD-library DIN 471 reference writes the ring in the YZ plane
    // with the lugs toward +Y and the near face at x = s/2. Keep the library's
    // default XY-plane, z = 0..s frame and map only the golden output.
    let (_x0, _x1, _y0, _y1, z0, z1) = component.bounding_box()
    let thickness = z1 - z0
    component = component
      .rotate_x(90.0)
      .rotate_z(90.0)
      .translate(x=thickness / 2.0)
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
