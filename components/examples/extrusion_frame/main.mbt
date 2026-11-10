///|
/// components/examples/extrusion_frame
///
/// Generate a generic T-slot rectangular frame:
///
/// ```bash
/// moon run --target native components/examples/extrusion_frame -- \
///   --width 400 --depth 300 --height 500 --series 2020 -o frame.step
/// ```
///
/// The profile is a generic engineering envelope, not a vendor-compatible
/// standard. Verify slot geometry against the intended manufacturer.
async fn main {
  let spec = {
    "width": @cli.opt_double(
      400.0,
      help="Frame width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "depth": @cli.opt_double(
      300.0,
      help="Frame depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      500.0,
      help="Frame height in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "series": @cli.opt_string(help="Generic series: 2020, 2040, 3030, 4040"),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the frame bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/extrusion_frame",
      description="Generate a generic T-slot rectangular frame.",
    )
    is Some(args) else {
    return
  }
  let profile = match
    parse_series(args.string_opt("series").unwrap_or("2020")) {
    Some(p) => p
    None => {
      @cli.eprintln("error: unsupported series (use 2020, 2040, 3030, or 4040)")
      abort("")
    }
  }
  let width = args.double("width")
  let depth = args.double("depth")
  let height = args.double("height")
  let frame = match @assemblies.extrusion_frame(width, depth, height, profile) {
    Ok(a) => a
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => frame.write_assembly_step(out_path)
    "flat" => frame.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}

///|
fn parse_series(name : String) -> @profiles.TSlotProfile? {
  match name {
    "2020" => Some(@profiles.TSlotProfile::generic_2020())
    "2040" => Some(@profiles.TSlotProfile::generic_2040())
    "3030" => Some(@profiles.TSlotProfile::generic_3030())
    "4040" => Some(@profiles.TSlotProfile::generic_4040())
    _ => None
  }
}
