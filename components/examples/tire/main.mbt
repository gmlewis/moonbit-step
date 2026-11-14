///|
/// components/examples/tire
///
/// Generate a parameterized wheel envelope. The defaults are measured from
/// the owner-authored model in `components/testdata/golden/external/tire.step`.
///
/// ```bash
/// moon run components/examples/tire -- -o /tmp/tire.step
/// moon run components/examples/tire -- \
///   --tireOuter 152.4 --tireInner 101.6 --tireWidth 25.4 \
///   --hubOuter 19.05 --hubBore 9.525 --hubLength 25.4 \
///   --hubInset 12.7 --insetThickness 1.5 --ribThickness 1.5 --ribs 5 \
///   -o /tmp/tire-small.step
/// ```
async fn main {
  let base = @motion.tire_spec()
  let spec = {
    "tireOuter": @cli.opt_double(
      base.tire_outer_diameter_mm,
      help="Tire outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "tireInner": @cli.opt_double(
      base.tire_inner_diameter_mm,
      help="Tire inner diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "tireWidth": @cli.opt_double(
      base.tire_width_mm,
      help="Tire width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "hubOuter": @cli.opt_double(
      base.hub_outer_diameter_mm,
      help="Hub outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "hubBore": @cli.opt_double(
      base.hub_bore_diameter_mm,
      help="Hub bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "hubLength": @cli.opt_double(
      base.hub_length_mm,
      help="Hub length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "hubInset": @cli.opt_double(
      base.hub_inset_mm,
      help="Axial distance from the outer face to the inset plate in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "insetThickness": @cli.opt_double(
      base.inset_thickness_mm,
      help="Inset plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "ribThickness": @cli.opt_double(
      base.rib_thickness_mm,
      help="Radial rib thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "ribs": @cli.opt_int(base.rib_count, help="Number of radial ribs", min=3),
    "ribPhase": @cli.opt_double(
      base.rib_phase_deg,
      help="First rib phase in degrees",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the wheel bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/tire",
      description="Generate a parameterized wheel and tire envelope.",
    )
    is Some(args) else {
    return
  }
  let measured : @motion.TireSpec = {
    tire_outer_diameter_mm: args.double("tireOuter"),
    tire_inner_diameter_mm: args.double("tireInner"),
    tire_width_mm: args.double("tireWidth"),
    hub_outer_diameter_mm: args.double("hubOuter"),
    hub_bore_diameter_mm: args.double("hubBore"),
    hub_length_mm: args.double("hubLength"),
    hub_inset_mm: args.double("hubInset"),
    inset_thickness_mm: args.double("insetThickness"),
    rib_thickness_mm: args.double("ribThickness"),
    rib_count: args.int("ribs"),
    rib_phase_deg: args.double("ribPhase"),
  }
  let wheel = match @motion.tire(measured) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = wheel.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  wheel.write_step(args.string_opt("out"), checked=true)
}
