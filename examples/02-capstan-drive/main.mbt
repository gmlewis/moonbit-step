///|
/// 02-capstan-drive
///
/// Parametric zero-backlash capstan / cable drive (`components/capstan`):
/// a small input capstan drum driving a larger output drum or compact arc
/// sector via tensioned tangent cable strands.

///|
async fn main {
  let spec = {
    "capstanRadius": @cli.opt_double(
      8.0,
      help="Small input capstan drum radius in mm (default 8.0)",
      min=3.0,
    ),
    "drivenRadius": @cli.opt_double(
      48.0,
      help="Large driven drum/sector radius in mm (default 48.0)",
      min=10.0,
    ),
    "cableDiam": @cli.opt_double(
      1.5,
      help="Cable / wire-rope diameter in mm (default 1.5)",
      min=0.3,
    ),
    "drumWidth": @cli.opt_double(
      16.0,
      help="Axial width of both drums in mm (default 16.0)",
      min=4.0,
    ),
    "travelDeg": @cli.opt_double(
      180.0,
      help="Output angular travel in degrees (30-360; <360 builds a compact arc sector, default 180)",
      min=30.0,
    ),
    "clearance": @cli.opt_double(
      4.0,
      help="Radial gap between the two drum outer circumferences in mm (default 4.0)",
      min=0.0,
    ),
    "crossed": @cli.flag(
      help="Use figure-8 crossed cable (reverses output direction)",
    ),
    "out": @cli.opt_string(
      help="Output STEP file path (default: stdout)",
      short='o',
    ),
    "scScript": @cli.opt_string(
      help="Write a native SolidCraft JSON command script for live GUI streaming",
    ),
  }
  guard @cli.parse(
      spec,
      prog="02-capstan-drive",
      description="Parametric zero-backlash capstan / cable drive.",
    )
    is Some(args) else {
    return
  }

  let params = match
    @capstan.CapstanParams::new(
      capstan_radius_mm=args.double("capstanRadius"),
      driven_radius_mm=args.double("drivenRadius"),
      cable_diameter_mm=args.double("cableDiam"),
      drum_width_mm=args.double("drumWidth"),
      travel_deg=args.double("travelDeg"),
      clearance_mm=args.double("clearance"),
      crossed=args.flag("crossed"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.to_string())
      abort("")
    }
  }
  let layout = @capstan.capstan_layout(params)
  let comp = match @capstan.capstan_drive(params) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.to_string())
      abort("")
    }
  }

  match args.string_opt("scScript") {
    Some(sc_path) => {
      comp.to_design().write_solidcraft_script(sc_path)
      println(
        "Capstan drive: \{@cad.fmt_double(layout.signed_reduction, Some(0.1))}:1, center_dist=\{@cad.fmt_double(layout.center_distance_mm, Some(0.1))} mm, wraps=\{layout.required_wraps}, eff=\{@cad.fmt_double(layout.efficiency * 100.0, Some(0.1))}%",
      )
      println("Wrote SolidCraft script: " + sc_path)
      return
    }
    None => ()
  }

  comp.write_step(args.string_opt("out"))
}
