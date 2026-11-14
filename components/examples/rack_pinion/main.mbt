///|
/// components/examples/rack_pinion
///
/// Build a rack-and-pinion layout with the basic rack and an involute spur
/// pinion:
///
/// ```bash
/// moon run components/examples/rack_pinion -- \
///   --module 2 --pinionTeeth 20 --rackTeeth 20 -o rack-pinion.step
/// moon run components/examples/rack_pinion -- --mode assembly \
///   -o rack-pinion-assembly.step
/// ./run-example.sh rack_pinion --view       # owner
/// ./run-example.sh --headless rack_pinion    # agents
/// ```
///
/// The rack pitch plane is taken from `rack_pinion_layout`; the pinion is placed
/// at the pitch-radius centre distance with a half-pitch phase. This is a
/// static layout, not a kinematic or contact solver. The rack flanks are exact
/// straight basic-rack flanks; the pinion is an involute approximation and the
/// two tooth forms do not claim exact conjugacy.
async fn main {
  let spec = {
    "module": @cli.opt_double(
      2.0,
      help="Gear module in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pinionTeeth": @cli.opt_int(20, help="Pinion tooth count"),
    "rackTeeth": @cli.opt_int(20, help="Rack tooth count"),
    "faceWidth": @cli.opt_double(
      10.0,
      help="Pinion face width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      10.0,
      help="Rack thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "baseThickness": @cli.opt_double(
      6.0,
      help="Rack base thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bore": @cli.opt_double(8.0, help="Pinion bore in mm", min=0.0),
    "backlash": @cli.opt_double(
      0.1,
      help="Pinion tooth-thickness backlash in mm",
      min=0.0,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/rack_pinion",
      description="Build a rack-and-pinion layout from the basic rack and an involute pinion.",
    )
    is Some(args) else {
    return
  }
  let module_mm = args.double("module")
  let pinion_teeth = args.int("pinionTeeth")
  let rack_teeth = args.int("rackTeeth")
  let layout = match
    @mechanisms.rack_pinion_layout(module_mm, rack_teeth, pinion_teeth) {
    Ok(l) => l
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let rack = match
    @mechanisms.rack_gear(
      module_mm,
      rack_teeth,
      args.double("baseThickness"),
      args.double("thickness"),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pinion = match
    @gears.SpurGearParams::new(
      module_mm~,
      teeth=pinion_teeth,
      pressure_angle_deg=20.0,
      face_width_mm=args.double("faceWidth"),
      bore_diameter_mm=args.double("bore"),
      backlash_mm=args.double("backlash"),
    ) {
    Ok(params) =>
      match @gears.spur_gear(params, detail=@common.DetailLevel::Detailed) {
        Ok(c) => c.rotate_z(180.0 / pinion_teeth.to_double())
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let rack_pitch_y = args.double("baseThickness") + layout.pitch_line_mm
  let pinion_y = rack_pitch_y + layout.center_distance_mm
  let pitch = @math.PI * module_mm
  let assembly = @assemblies.Assembly::new(
      name="rack-pinion",
      description="Basic rack and involute pinion at the layout pitch-plane centre distance.",
    )
    .add(rack, instance_name="rack")
    .add(
      pinion,
      placement=@common.Placement::translation(0.5 * pitch, pinion_y, 0.0),
      instance_name="pinion",
    )
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
