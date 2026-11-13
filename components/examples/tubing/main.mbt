///|
/// components/examples/tubing
///
/// Generate commodity tubing and printed-to-metal adapter primitives:
///
/// ```bash
/// moon run components/examples/tubing -- --part emt --trade 1/2 --length 304.8 -o emt.step
/// moon run components/examples/tubing -- --part collar --bore 8 --outer 16 --width 8 -o collar.step
/// moon run components/examples/tubing -- --part adapter --tubeOD 17.9324 --clearance 0.5 -o adapter.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: emt (default), collar, adapter",
    ),
    "trade": @cli.opt_string(
      help="EMT trade size: 1/2 (default), 3/4, 1, 1-1/4, 1-1/2, 2",
    ),
    "length": @cli.opt_double(
      304.8,
      help="Tube or collar length in mm",
      min=0.0,
    ),
    "bore": @cli.opt_double(8.0, help="Collar bore in mm", min=0.0),
    "outer": @cli.opt_double(
      16.0,
      help="Collar outside diameter in mm",
      min=0.0,
    ),
    "width": @cli.opt_double(8.0, help="Collar width in mm", min=0.0),
    "tubeOD": @cli.opt_double(
      17.9324,
      help="Adapter tube outside diameter in mm",
      min=0.0,
    ),
    "clearance": @cli.opt_double(
      0.5,
      help="Adapter tube clearance in mm",
      min=0.0,
    ),
    "plateWidth": @cli.opt_double(
      60.0,
      help="Adapter plate width in mm",
      min=0.0,
    ),
    "plateHeight": @cli.opt_double(
      40.0,
      help="Adapter plate height in mm",
      min=0.0,
    ),
    "plateThickness": @cli.opt_double(
      5.0,
      help="Adapter plate thickness in mm",
      min=0.0,
    ),
    "boltHole": @cli.opt_double(
      5.5,
      help="Adapter bolt hole diameter in mm",
      min=0.0,
    ),
    "boltSpacing": @cli.opt_double(
      40.0,
      help="Adapter bolt spacing in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/tubing",
      description="Generate EMT tube, shaft collar, and tube mount plate primitives.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("emt")
  let component = match part_kind {
    "collar" =>
      match
        @motion.shaft_collar(
          args.double("bore"),
          args.double("outer"),
          args.double("width"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "adapter" =>
      match
        @stock.tube_mount_plate(
          args.double("tubeOD"),
          args.double("clearance"),
          args.double("plateWidth"),
          args.double("plateHeight"),
          args.double("plateThickness"),
          args.double("boltHole"),
          args.double("boltSpacing"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    _ => {
      let trade = args.string_opt("trade").unwrap_or("1/2")
      let size = match @motion.emt_size(trade) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match @motion.emt_tube(size, args.double("length")) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
