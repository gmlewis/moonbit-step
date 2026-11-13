///|
/// components/examples/planetary
///
/// Generate a straight-spur planetary gear set:
///
/// ```bash
/// moon run components/examples/planetary -- \
///   --module 2 --sunTeeth 12 --planetTeeth 12 --planets 3 -o planetary.step
/// ```
///
/// Ring teeth are derived as `sun + 2 * planet`; the equally-spaced-planet
/// condition is enforced. The internal ring tooth form is an approximation.
async fn main {
  let spec = {
    "module": @cli.opt_double(
      2.0,
      short='m',
      help="Gear module in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "sunTeeth": @cli.opt_int(12, short='s', help="Sun tooth count"),
    "planetTeeth": @cli.opt_int(12, short='p', help="Planet tooth count"),
    "planets": @cli.opt_int(
      3,
      short='n',
      help="Number of equally spaced planets",
    ),
    "pressureAngle": @cli.opt_double(
      20.0,
      short='A',
      help="Pressure angle in degrees",
    ),
    "faceWidth": @cli.opt_double(
      10.0,
      short='w',
      help="Face width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "sunBore": @cli.opt_double(
      6.0,
      short='b',
      help="Sun bore diameter in mm",
      min=0.0,
    ),
    "planetBore": @cli.opt_double(
      4.0,
      short='B',
      help="Planet bore diameter in mm",
      min=0.0,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/planetary",
      description="Generate a straight-spur planetary gear set.",
    )
    is Some(args) else {
    return
  }
  let params = match
    @gears.PlanetaryParams::new(
      module_mm=args.double("module"),
      sun_teeth=args.int("sunTeeth"),
      planet_teeth=args.int("planetTeeth"),
      planet_count=args.int("planets"),
      pressure_angle_deg=args.double("pressureAngle"),
      face_width_mm=args.double("faceWidth"),
      sun_bore_mm=args.double("sunBore"),
      planet_bore_mm=args.double("planetBore"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let set = match @gears.planetary_gear_set(params, smooth=true) {
    Ok(a) => a
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = set.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => set.write_assembly_step(out_path)
    "flat" => set.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
