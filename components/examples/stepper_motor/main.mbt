///|
/// components/examples/stepper_motor
///
/// Generate a NEMA stepper-motor envelope:
///
/// ```bash
/// moon run components/examples/stepper_motor -- \
///   --frame NEMA17 --bodyLength 40 -o nema17.step
/// ```
///
/// The body, pilot boss, and shaft are separate watertight solids.
async fn main {
  let spec = {
    "frame": @cli.opt_string(
      short='f',
      help="NEMA frame: NEMA17 (default) or NEMA23",
    ),
    "bodyLength": @cli.opt_double(
      40.0,
      short='l',
      help="Motor body length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftLength": @cli.opt_double(
      0.0,
      short='s',
      help="Shaft length in mm (0 = frame default)",
      min=0.0,
    ),
    "shaftDiameter": @cli.opt_double(
      0.0,
      short='d',
      help="Shaft diameter in mm (0 = frame default)",
      min=0.0,
    ),
    "pilotDiameter": @cli.opt_double(
      0.0,
      help="Pilot boss diameter in mm (0 = frame default)",
      min=0.0,
    ),
    "detail": @cli.opt_string(
      short='D',
      help="Detail: simplified, detailed (default), full",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the motor bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/stepper_motor",
      description="Generate a NEMA stepper-motor envelope.",
    )
    is Some(args) else {
    return
  }
  let frame_name = args.string_opt("frame").unwrap_or("NEMA17")
  let frame = match @motors.nema_frame(frame_name) {
    Ok(f) => f
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let shaft_length = if args.double("shaftLength") > 0.0 {
    args.double("shaftLength")
  } else {
    frame.default_shaft_length_mm
  }
  let shaft_diameter = if args.double("shaftDiameter") > 0.0 {
    args.double("shaftDiameter")
  } else {
    frame.shaft_diameter_mm
  }
  let pilot_diameter = if args.double("pilotDiameter") > 0.0 {
    args.double("pilotDiameter")
  } else {
    frame.pilot_diameter_mm
  }
  let part = match
    @motors.nema_stepper_motor(
      frame,
      args.double("bodyLength"),
      shaft_length_mm=shaft_length,
      shaft_diameter_mm=shaft_diameter,
      pilot_diameter_mm=pilot_diameter,
      detail=parse_detail(args.string_opt("detail").unwrap_or("detailed")),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  part.write_step(args.string_opt("out"), checked=true)
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "simplified" | "simple" => @common.DetailLevel::Simplified
    "full" | "fully-modeled" | "fully_modeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Detailed
  }
}
