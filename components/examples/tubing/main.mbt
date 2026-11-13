///|
/// components/examples/tubing
///
/// Generate commodity tubing and printed-to-metal adapter primitives:
///
/// ```bash
/// moon run components/examples/tubing -- --part emt --trade 1/2 --length 304.8 -o emt.step
/// moon run components/examples/tubing -- --part collar --bore 8 --outer 16 --width 8 -o collar.step
/// moon run components/examples/tubing -- --part adapter --tubeOD 17.9324 --clearance 0.5 -o adapter.step
/// moon run components/examples/tubing -- --part endcap --trade 1/2 -o endcap.step
/// moon run components/examples/tubing -- --part clamp --trade 1/2 -o clamp.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: emt (default), collar, adapter, endcap, clamp",
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
    "capThickness": @cli.opt_double(
      3.0,
      help="End cap disc thickness in mm",
      min=0.0,
    ),
    "plugLength": @cli.opt_double(
      15.0,
      help="End cap plug length in mm",
      min=0.0,
    ),
    "plugClearance": @cli.opt_double(
      0.25,
      help="End cap plug clearance in mm",
      min=0.0,
    ),
    "clampLength": @cli.opt_double(
      20.0,
      help="Split clamp length in mm",
      min=0.0,
    ),
    "clampWall": @cli.opt_double(
      3.0,
      help="Split clamp ring wall in mm",
      min=0.0,
    ),
    "clampClearance": @cli.opt_double(
      0.5,
      help="Split clamp bore clearance in mm",
      min=0.0,
    ),
    "clampGap": @cli.opt_double(
      2.0,
      help="Split clamp closure gap in mm",
      min=0.0,
    ),
    "boltDiameter": @cli.opt_double(
      5.5,
      help="Split clamp cross-bolt diameter in mm",
      min=0.0,
    ),
    "clampEarLength": @cli.opt_double(
      8.0,
      help="Split clamp ear length in mm",
      min=0.0,
    ),
    "clampEarHeight": @cli.opt_double(
      6.0,
      help="Split clamp ear height in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/tubing",
      description="Generate EMT tube, shaft collar, tube mount plate, end cap, and split clamp primitives.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("emt")
  let component = match part_kind {
    "endcap" => {
      let trade = args.string_opt("trade").unwrap_or("1/2")
      let size = match @motion.emt_size(trade) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match
        @motion.emt_end_cap(
          size,
          args.double("capThickness"),
          args.double("plugLength"),
          plug_clearance_mm=args.double("plugClearance"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    "clamp" => {
      let trade = args.string_opt("trade").unwrap_or("1/2")
      let size = match @motion.emt_size(trade) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match
        @motion.emt_split_clamp(
          size,
          args.double("clampLength"),
          wall_mm=args.double("clampWall"),
          clearance_mm=args.double("clampClearance"),
          gap_mm=args.double("clampGap"),
          bolt_diameter_mm=args.double("boltDiameter"),
          ear_length_mm=args.double("clampEarLength"),
          ear_height_mm=args.double("clampEarHeight"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
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
