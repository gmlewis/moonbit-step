///|
/// components/examples/mechanism_assembly
///
/// Assemble a clevis, a rod end, and a pin from the mechanism kit:
///
/// ```bash
/// moon run components/examples/mechanism_assembly -- -o clevis-rod-end.step
/// moon run components/examples/mechanism_assembly -- \
///   --gap 12 --eyeWidth 11.6 --pinDiameter 6 -o assembly.step
/// ./run-example.sh mechanism_assembly --view      # owner
/// ./run-example.sh --headless mechanism_assembly   # agents
/// ```
///
/// The rod end is placed by a named `MatePair` between the clevis
/// `pin-bore-a` and the rod-end `eye-bore`, with an offset that centres the eye
/// in the fork gap. The pin is placed coaxially through both prongs and the
/// eye. `--mode assembly` writes the product/occurrence structure instead of
/// the flat STEP export.
async fn main {
  let spec = {
    "clevisWidth": @cli.opt_double(
      30.0,
      help="Clevis base width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "clevisDepth": @cli.opt_double(
      20.0,
      help="Clevis base depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "baseThickness": @cli.opt_double(
      6.0,
      help="Clevis base thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "prongThickness": @cli.opt_double(
      5.0,
      help="Clevis prong thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "gap": @cli.opt_double(
      12.0,
      help="Clevis fork gap in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pinDiameter": @cli.opt_double(
      6.0,
      help="Pin and bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pinExtension": @cli.opt_double(
      2.0,
      help="Pin extension beyond the prongs in mm",
      min=0.0,
    ),
    "eyeOuter": @cli.opt_double(
      20.0,
      help="Rod-end eye outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "eyeWidth": @cli.opt_double(
      11.6,
      help="Rod-end eye width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shankDiameter": @cli.opt_double(
      8.0,
      help="Rod-end shank diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shankLength": @cli.opt_double(
      40.0,
      help="Rod-end shank length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mechanism_assembly",
      description="Assemble a clevis, rod end, and pin with a named mate pair.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("clevisWidth")
  let depth = args.double("clevisDepth")
  let base_thickness = args.double("baseThickness")
  let prong_thickness = args.double("prongThickness")
  let gap = args.double("gap")
  let pin_diameter = args.double("pinDiameter")
  let eye_width = args.double("eyeWidth")
  let extension = args.double("pinExtension")
  if eye_width >= gap {
    @cli.eprintln("error: eye width must be smaller than the fork gap")
    abort("")
  }
  let clevis = match
    @mechanisms.clevis(
      width, depth, base_thickness, prong_thickness, gap, pin_diameter,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let rod = match
    @mechanisms.rod_end(
      args.double("eyeOuter"),
      pin_diameter,
      eye_width,
      args.double("shankDiameter"),
      args.double("shankLength"),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pin_length = 2.0 * prong_thickness + gap + 2.0 * extension
  let pin = match
    @mechanisms.clevis_pin(
      pin_diameter,
      pin_length,
      pin_diameter * 1.6,
      pin_diameter * 0.3,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let eye_offset = (gap - eye_width) / 2.0
  let pair = @common.MatePair::new(
    parent="eye-seat",
    child="eye-bore",
    offset_mm=eye_offset,
    description="rod-end eye centred in the clevis gap",
  )
  let assembly = @assemblies.Assembly::new(
    name="clevis-rod-end",
    description="Clevis, rod end, and pin assembled by named mate connectors.",
  ).add(clevis, instance_name="clevis")
  let (assembly, _alignment) = match
    assembly.add_mate_pair("clevis", rod, pair, instance_name="rod-end") {
    Ok(result) => result
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let lower_z = base_thickness
  let assembly = assembly.add(
    pin,
    placement=@common.Placement::translation(0.0, 0.0, lower_z - extension),
    instance_name="pin",
  )
  if !assembly.is_connected() {
    @cli.eprintln("error: assembled parts are not connected")
    abort("")
  }
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
