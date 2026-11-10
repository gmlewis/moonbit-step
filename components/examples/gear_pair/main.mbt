///|
/// components/examples/gear_pair
///
/// Generate a two-gear involute spur gear pair:
///
/// ```bash
/// moon run --target native components/examples/gear_pair -- \
///   --module 2 --teeth 20 --mateTeeth 40 -o pair.step
/// ```
async fn main {
  let spec = {
    "module": @cli.opt_double(
      2.0,
      short='m',
      help="Gear module in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "teeth": @cli.opt_int(20, short='n', help="Driver tooth count"),
    "mateTeeth": @cli.opt_int(40, short='N', help="Driven tooth count"),
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
    "bore": @cli.opt_double(
      8.0,
      short='b',
      help="Driver bore diameter in mm",
      min=0.0,
    ),
    "mateBore": @cli.opt_double(
      10.0,
      short='B',
      help="Driven bore diameter in mm",
      min=0.0,
    ),
    "offset": @cli.opt_double(
      0.05,
      help="Centre-distance offset in mm (backlash)",
    ),
    "rootFillet": @cli.opt_double(
      0.0,
      short='f',
      help="Root fillet radius in mm (0 = sharp root)",
      min=0.0,
    ),
    "tipChamfer": @cli.opt_double(
      0.0,
      short='c',
      help="Tip chamfer distance in mm (0 = sharp tip)",
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
      prog="components/examples/gear_pair",
      description="Generate an involute spur gear pair.",
    )
    is Some(args) else {
    return
  }
  let module_mm = args.double("module")
  let teeth = args.int("teeth")
  let mate_teeth = args.int("mateTeeth")
  let pressure = args.double("pressureAngle")
  let face = args.double("faceWidth")
  let bore = args.double("bore")
  let mate_bore = args.double("mateBore")
  let offset = args.double("offset")
  let root_fillet = args.double("rootFillet")
  let tip_chamfer = args.double("tipChamfer")
  let driver = match
    @gears.SpurGearParams::new(
      module_mm~,
      teeth~,
      pressure_angle_deg=pressure,
      face_width_mm=face,
      bore_diameter_mm=bore,
      root_fillet_radius_mm=root_fillet,
      tip_chamfer_mm=tip_chamfer,
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let driven = match
    @gears.SpurGearParams::new(
      module_mm~,
      teeth=mate_teeth,
      pressure_angle_deg=pressure,
      face_width_mm=face,
      bore_diameter_mm=mate_bore,
      root_fillet_radius_mm=root_fillet,
      tip_chamfer_mm=tip_chamfer,
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pair = match @gears.gear_pair(driver, driven, offset_mm=offset) {
    Ok(a) => a
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = pair.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => pair.write_assembly_step(out_path)
    "flat" => pair.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
