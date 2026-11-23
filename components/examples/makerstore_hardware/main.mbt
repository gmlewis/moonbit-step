///|
/// components/examples/makerstore_hardware
///
/// Generate one Maker Store USA hardware part:
///
/// ```bash
/// # Metric aluminum spacer OD 10 / ID 5 (SHIM-SPAC), length 10 mm by default
/// moon run components/examples/makerstore_hardware -- --part spacer --length 20 -o spacer.step
///
/// # Standard metric thrust bearing (BEAR-F)
/// moon run components/examples/makerstore_hardware -- --part thrust --size F8-16M -o f8-16m.step
///
/// # 20-series hex sliding T-nut (HARD-TNUT-SLIDING)
/// moon run components/examples/makerstore_hardware -- --part tnut20 --thread M5 -o tnut20.step
///
/// # 40-series sliding block T-nut (HARD-40S-TNUT-STEEL-SLID-18)
/// moon run components/examples/makerstore_hardware -- --part tnut40 --thread M6 -o tnut40.step
///
/// # Gusseted V-Slot corner bracket (BRAC-90CAST at 20 mm, BRAC-40S at 40 mm)
/// moon run components/examples/makerstore_hardware -- --part bracket --leg 20 -o bracket.step
/// ```
///
/// Every part is a published-envelope reconstruction with declared omissions;
/// the STEP header carries the Maker Store SKU, URL, and price.
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: spacer (default), thrust, tnut20, tnut40, bracket",
    ),
    "length": @cli.opt_double(
      10.0,
      short='l',
      help="Spacer length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "outer": @cli.opt_double(
      10.0,
      help="Spacer outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "inner": @cli.opt_double(
      5.0,
      help="Spacer bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "size": @cli.opt_string(
      short='s',
      help="Thrust bearing size: F5-10M, F5-12M, F6-12M, F8-16M",
    ),
    "thread": @cli.opt_string(short='t', help="T-nut thread (e.g. M5)"),
    "leg": @cli.opt_double(
      20.0,
      help="Corner bracket leg length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/makerstore_hardware",
      description="Generate a Maker Store USA hardware part.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("spacer")
  let component = match part_kind {
    "spacer" =>
      unwrap_any(
        @motion.makerstore_aluminum_spacer(
          length_mm=args.double("length"),
          outer_diameter_mm=args.double("outer"),
          inner_diameter_mm=args.double("inner"),
        ),
      )
    "thrust" => {
      let size = unwrap_any(
        @motion.thrust_bearing_size(args.string_opt("size").unwrap_or("F5-10M")),
      )
      unwrap_any(@motion.thrust_bearing(size))
    }
    "tnut20" =>
      unwrap_any(
        @fasteners.makerstore_hex_tnut(
          args.string_opt("thread").unwrap_or("M5"),
        ),
      )
    "tnut40" =>
      unwrap_any(
        @fasteners.makerstore_sliding_tnut(
          args.string_opt("thread").unwrap_or("M5"),
        ),
      )
    "bracket" =>
      unwrap_any(@profiles.makerstore_corner_bracket(leg_mm=args.double("leg")))
    other => {
      @cli.eprintln("error: unknown part: " + other)
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}

///|
/// unwrap_any returns a value or aborts with the typed error message.
async fn[T] unwrap_any(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(v) => v
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
}
