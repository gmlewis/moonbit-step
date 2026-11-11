///|
/// components/examples/motion_stack
///
/// Generate a shaft / bearing / spacer stack:
///
/// ```bash
/// moon run components/examples/motion_stack -- \
///   --bearing 608 --shaftDiameter 8 --shaftLength 40 -o motion.step
/// ```
///
/// The bearings are simplified envelopes: rings plus cylindrical roller
/// proxies, not exact catalogue internals.
async fn main {
  let spec = {
    "bearing": @cli.opt_string(
      short='b',
      help="Bearing designation, e.g. 608, 6204",
    ),
    "shaftDiameter": @cli.opt_double(
      8.0,
      short='d',
      help="Shaft diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftLength": @cli.opt_double(
      40.0,
      short='l',
      help="Shaft length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "spacerLength": @cli.opt_double(
      10.0,
      help="Spacer length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "detail": @cli.opt_string(
      short='D',
      help="Bearing detail: simplified (default), detailed, full",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/motion_stack",
      description="Generate a shaft, bearing, and spacer assembly.",
    )
    is Some(args) else {
    return
  }
  let bearing_name = args.string_opt("bearing").unwrap_or("608")
  let shaft_diameter = args.double("shaftDiameter")
  let shaft_length = args.double("shaftLength")
  let spacer_length = args.double("spacerLength")
  let shaft = match @motion.shaft(shaft_diameter, shaft_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_detail = parse_bearing_detail(
    args.string_opt("detail").unwrap_or("simplified"),
  )
  let bearing = match
    @motion.bearing_by_designation(bearing_name, detail=bearing_detail) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_size = match @motion.bearing_size(bearing_name) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if shaft_diameter > bearing_size.bore_mm + 1.0e-9 {
    @cli.eprintln(
      "error: shaft diameter must not exceed the bearing bore (\{bearing_size.bore_mm} mm)",
    )
    abort("")
  }
  let spacer_outer = shaft_diameter * 1.5
  let spacer = match
    @motion.spacer(spacer_outer, shaft_diameter, spacer_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_a_z = 5.0
  let bearing_b_z = shaft_length - bearing_size.width_mm - 5.0
  if bearing_b_z <= bearing_a_z + bearing_size.width_mm {
    @cli.eprintln("error: shaft is too short for two bearings")
    abort("")
  }
  let spacer_z = bearing_a_z + bearing_size.width_mm + 1.0
  if spacer_z + spacer_length > bearing_b_z {
    @cli.eprintln("error: spacer does not fit between the bearings")
    abort("")
  }
  let name = "motion-stack-\{bearing_name}"
  let assembly = @assemblies.Assembly::new(
      name~,
      description="Shaft with two simplified bearings and a spacer. Bearing rolling elements are cylindrical proxies.",
    )
    .add(shaft, instance_name="shaft")
    .add(
      bearing,
      placement=@common.Placement::translation(0.0, 0.0, bearing_a_z),
      instance_name="bearing-a",
    )
    .add(
      bearing,
      placement=@common.Placement::translation(0.0, 0.0, bearing_b_z),
      instance_name="bearing-b",
    )
    .add(
      spacer,
      placement=@common.Placement::translation(0.0, 0.0, spacer_z),
      instance_name="spacer",
    )
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(out_path)
    "flat" => assembly.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}

///|
fn parse_bearing_detail(text : String) -> @common.DetailLevel {
  match text {
    "detailed" | "detail" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fully_modeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}
