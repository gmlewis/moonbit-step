///|
/// components/examples/makerstore_l_plate
///
/// Generate a Maker Store 20-series L plate / bracket with a centred hole grid
/// on both legs.
///
/// ```bash
/// # The flagship 40 x 40 L plate (SKU PLATE-40X40L), 3 x 3 holes on 10 mm centres
/// moon run components/examples/makerstore_l_plate -- -o l-40x40.step
///
/// # The 40 x 80 L plate (SKU PLATE-40X80L)
/// moon run components/examples/makerstore_l_plate -- --part l40x80 -o l-40x80.step
///
/// # Override the grid pitch and hole diameter
/// moon run components/examples/makerstore_l_plate -- \
///   --pitch 20 --hole 5.5 -o l-pitch20.step
/// ```
///
/// The 40 x 40 geometry matches the Maker Store dimensioned drawing: 40 x 40 mm
/// legs, 3 mm thick, 3 x 3 5 mm holes at 10 mm centres with 10 mm margins.
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Preset: l40x40 (default) or l40x80",
    ),
    "legA": @cli.opt_double(
      0.0,
      help="Base leg length in mm (0 = use the preset)",
      min=0.0,
    ),
    "legB": @cli.opt_double(
      0.0,
      help="Upright leg length in mm (0 = use the preset)",
      min=0.0,
    ),
    "width": @cli.opt_double(
      0.0,
      help="Leg width in mm (0 = use the preset)",
      min=0.0,
    ),
    "thickness": @cli.opt_double(
      0.0,
      help="Plate thickness in mm (0 = use the preset)",
      min=0.0,
    ),
    "hole": @cli.opt_double(
      0.0,
      help="Hole diameter in mm (0 = use 5)",
      min=0.0,
    ),
    "pitch": @cli.opt_double(
      0.0,
      help="Hole grid pitch in mm (0 = use 10)",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/makerstore_l_plate",
      description="Generate a Maker Store 20-series L plate / bracket.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("l40x40")
  let (leg_a, leg_b, width) = match part_kind {
    "l40x40" | "40x40" | "40x40l" => (40.0, 40.0, 40.0)
    "l40x80" | "40x80" | "40x80l" => (80.0, 40.0, 40.0)
    other => {
      @cli.eprintln(
        "error: unknown part preset: " + other + " (use l40x40 or l40x80)",
      )
      abort("")
    }
  }
  let leg_a_final = overridden(args.double("legA"), leg_a)
  let leg_b_final = overridden(args.double("legB"), leg_b)
  let width_final = overridden(args.double("width"), width)
  let thickness = overridden(args.double("thickness"), 3.0)
  let hole = overridden(args.double("hole"), 5.0)
  let pitch = overridden(args.double("pitch"), 10.0)
  let component = match
    @mechanisms.makerstore_l_plate(
      leg_a_mm=leg_a_final,
      leg_b_mm=leg_b_final,
      width_mm=width_final,
      thickness_mm=thickness,
      hole_diameter_mm=hole,
      pitch_mm=pitch,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
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
/// overridden returns the command-line value when supplied (positive), else the
/// preset default.
fn overridden(value : Double, default : Double) -> Double {
  if value > 0.0 {
    value
  } else {
    default
  }
}
