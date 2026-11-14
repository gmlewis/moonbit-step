///|
/// components/examples/adapters
///
/// Generate the generic parametric extrusion adapters:
///
/// ```bash
/// moon run components/examples/adapters -- --part motor -o motor-adapter.step
/// moon run components/examples/adapters -- \
///   --part channel -o channel-adapter.step
/// moon run components/examples/adapters -- \
///   --part clamp --tubeOD 17.9324 -o tube-clamp.step
/// ```
///
/// The motor and channel adapters are flat plates and use the flat writer. The
/// tube clamp is a layered ring/ear/base part and uses the OCCT-evaluated
/// union; without OCCT, use `--part motor` or `--part channel`.
async fn main {
  let spec = {
    "part": @cli.opt_string(help="Part: motor (default), channel, or clamp"),
    "frame": @cli.opt_string(
      help="NEMA frame for --part motor: NEMA17 or NEMA23",
    ),
    "extrusionPitch": @cli.opt_double(
      40.0,
      help="Extrusion T-nut pitch in mm for --part motor",
      min=0.0,
    ),
    "tubeOD": @cli.opt_double(
      17.9324,
      help="Tube outside diameter in mm for --part clamp",
      min=0.0,
    ),
    "length": @cli.opt_double(20.0, help="Tube clamp length in mm", min=0.0),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/adapters",
      description="Generate a generic extrusion adapter.",
    )
    is Some(args) else {
    return
  }
  let part = args.string_opt("part").unwrap_or("motor")
  let component = match part {
    "motor" => {
      let frame = match
        @motors.nema_frame(args.string_opt("frame").unwrap_or("NEMA17")) {
        Ok(f) => f
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      let pitch = if frame.designation == "NEMA23" {
        60.0
      } else {
        args.double("extrusionPitch")
      }
      let plate = if frame.designation == "NEMA23" {
        frame.bolt_spacing_mm + 34.0
      } else {
        frame.bolt_spacing_mm + 29.0
      }
      let thickness = if frame.designation == "NEMA23" { 8.0 } else { 6.0 }
      match
        @motors.motor_to_extrusion_adapter(
          frame, plate, plate, thickness, pitch,
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    "channel" =>
      match
        @stock.channel_to_extrusion_adapter(
          41.3, 47.6, 14.3, 20.0, 70.0, 48.0, 6.0,
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "clamp" =>
      match
        @stock.extrusion_to_tube_clamp(
          args.double("tubeOD"),
          args.double("length"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    other => {
      @cli.eprintln(
        "error: unknown part \{other}; use motor, channel, or clamp",
      )
      abort("")
    }
  }
  if part == "clamp" {
    component.write_step_evaluated(args.string_opt("out"))
  } else {
    component.write_step(args.string_opt("out"), checked=true)
  }
}
