///|
/// 01-worm-gear-drive
///
/// Parametric 90-degree right-angle worm gear drive (`components/worm`):
/// an orthogonal helical worm shaft meshing with an involute worm wheel,
/// reporting exact reduction ratio, lead angle, self-locking status, and
/// sliding-mesh efficiency.

///|
async fn main {
  let spec = {
    "module": @cli.opt_double(
      2.0,
      help="Axial module in mm (default 2.0)",
      min=0.5,
    ),
    "starts": @cli.opt_int(
      1,
      help="Number of worm thread starts (1-6, 1 is typically self-locking, default 1)",
      min=1,
    ),
    "wheelTeeth": @cli.opt_int(
      30,
      help="Number of teeth on the worm wheel (>= 12, default 30)",
      min=12,
    ),
    "wormRadius": @cli.opt_double(
      10.0,
      help="Worm pitch radius in mm (default 10.0)",
      min=3.0,
    ),
    "wormLength": @cli.opt_double(
      36.0,
      help="Worm threaded shaft length in mm (default 36.0)",
      min=10.0,
    ),
    "wheelWidth": @cli.opt_double(
      14.0,
      help="Worm wheel face width in mm (default 14.0)",
      min=4.0,
    ),
    "friction": @cli.opt_double(
      0.15,
      help="Sliding friction coefficient mu (default 0.15)",
      min=0.0,
    ),
    "tolerance": @cli.opt_double(
      0.10,
      help="Radial backlash/clearance in mm (default 0.10)",
      min=0.0,
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
      prog="01-worm-gear-drive",
      description="Parametric 90-degree right-angle worm gear drive.",
    )
    is Some(args) else {
    return
  }

  let params = match
    @worm.WormGearParams::new(
      module_mm=args.double("module"),
      worm_starts=args.int("starts"),
      wheel_teeth=args.int("wheelTeeth"),
      worm_pitch_radius_mm=args.double("wormRadius"),
      worm_length_mm=args.double("wormLength"),
      wheel_width_mm=args.double("wheelWidth"),
      friction_coeff=args.double("friction"),
      tolerance_mm=args.double("tolerance"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.to_string())
      abort("")
    }
  }
  let layout = @worm.worm_gear_layout(params)
  let comp = match @worm.worm_gear_drive(params) {
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
        "Worm drive: \{@cad.fmt_double(layout.reduction_ratio, Some(0.1))}:1, lead=\{@cad.fmt_double(layout.lead_angle_deg, Some(0.1))} deg, self_locking=\{layout.is_self_locking}, eff=\{@cad.fmt_double(layout.efficiency * 100.0, Some(0.1))}%",
      )
      println("Wrote SolidCraft script: " + sc_path)
      return
    }
    None => ()
  }

  comp.write_step(args.string_opt("out"))
}
