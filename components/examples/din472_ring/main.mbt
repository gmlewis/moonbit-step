///|
/// components/examples/din472_ring
///
/// Generate a DIN 472 internal retaining ring:
///
/// ```bash
/// moon run components/examples/din472_ring -- --size 20 -o din472-20.step
/// moon run components/examples/din472_ring -- --size 10 -o din472-10.step
/// moon run components/examples/din472_ring -- --size 40 -o din472-40.step
/// moon run components/examples/din472_ring -- --size 20 --goldenFrame -o ring-golden.step
/// ```
///
/// `--goldenFrame` is a comparison-only option: it rotates the ring into the
/// reference XY frame with lugs toward -Y. The CC0 12/20 mm references sit at
/// z = 0..s; the eight FreeCAD references are centered at z = 0, so those
/// outputs are also shifted axially by -s/2. The builder's default frame stays
/// XY-plane, z = 0..s, lugs +X.
/// Encoded outlines are 10/14/16/18/24/28/32/40 mm (CC BY-SA 4.0
/// FreeCAD-parts_library) and 12/20 mm (CC0 Innerscene). The eight FreeCAD
/// sizes reproduce the reference 45-degree edge chamfers and export through
/// OCCT; the 12/20 mm rings stay flat and sharp. The bore groove is declared
/// by a connector but is not modelled.
async fn main {
  let spec = {
    "size": @cli.opt_double(
      20.0,
      help="Nominal bore diameter in mm (encoded outlines: 10, 12, 14, 16, 18, 20, 24, 28, 32, 40)",
      min=0.0,
    ),
    "goldenFrame": @cli.flag(
      help="Emit the ring in the published reference frame (lugs -Y; FreeCAD sizes centered at z=0; comparison only)",
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
  let outline = match @fasteners.din472_outline(args.double("size")) {
    Ok(o) => o
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("goldenFrame") {
    component = component.rotate_z(-90.0)
    if outline.chamfer_mm > 0.0 {
      // The FreeCAD references are centred on z = 0.
      component = component.translate(z=-outline.thickness_mm / 2.0)
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if outline.chamfer_mm > 0.0 {
    // The FreeCAD reference sizes carry real chamfers; the flat writer refuses
    // edge features, so their accepted artifact is OCCT-evaluated. This path
    // also writes the named-connector sidecar when requested.
    component.write_step_evaluated(args.string_opt("out"))
  } else {
    component.write_step(args.string_opt("out"), checked=true)
  }
}
