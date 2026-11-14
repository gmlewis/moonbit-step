///|
/// components/examples/mechanism_design
///
/// Build a small mechanism from scratch with the typed parameter API and the
/// `@cad` primitive DSL:
///
/// ```bash
/// moon run components/examples/mechanism_design -- \
///   --length 140 --width 24 --pivot 8 -o linkage.step
/// moon run components/examples/mechanism_design -- \
///   --variant compact -o linkage-compact.step
/// ./run-example.sh mechanism_design --view      # owner: open in SolidCraft
/// ./run-example.sh --headless mechanism_design   # agents: generate only
/// ```
///
/// The mechanism is a linkage bar built by a `DesignFamily` (validated
/// parameters) with a base plate and two pivot pins added through the `@cad`
/// primitives. The `--variant` presets demonstrate named design variants.
/// The base plate and pins are nominal layers: the base is not drilled for the
/// pins, and no load or strength rating is implied.
async fn main {
  let spec = {
    "length": @cli.opt_double(
      120.0,
      short='l',
      help="Linkage length in mm",
      min=60.0,
      max=400.0,
    ),
    "width": @cli.opt_double(
      24.0,
      short='w',
      help="Linkage width in mm",
      min=12.0,
      max=80.0,
    ),
    "thickness": @cli.opt_double(
      6.0,
      short='t',
      help="Linkage thickness in mm",
      min=3.0,
      max=20.0,
    ),
    "pivot": @cli.opt_double(
      8.0,
      short='p',
      help="Pivot hole diameter in mm",
      min=4.0,
      max=20.0,
    ),
    "slotLength": @cli.opt_double(
      0.0,
      help="Adjustment slot length in mm",
      min=0.0,
      max=200.0,
    ),
    "slotWidth": @cli.opt_double(
      0.0,
      help="Adjustment slot width in mm",
      min=0.0,
      max=40.0,
    ),
    "baseThickness": @cli.opt_double(
      6.0,
      help="Base plate thickness in mm",
      min=2.0,
      max=30.0,
    ),
    "variant": @cli.opt_string(help="Named variant: compact or long"),
    "noBase": @cli.flag(help="Omit the base plate and pivot pins"),
    "evaluated": @cli.flag(
      help="Fuse layers and export an OCCT-evaluated STEP (requires OCCT)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mechanism_design",
      description="Design a small linkage mechanism with the typed parameter API.",
    )
    is Some(args) else {
    return
  }
  let family = match @mechanisms.linkage_family() {
    Ok(f) => f
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let parameters = match args.string_opt("variant") {
    Some(variant) =>
      match family.variant(variant) {
        Ok(p) => p
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    None =>
      match
        family.from_values([
          ("length", args.double("length")),
          ("width", args.double("width")),
          ("thickness", args.double("thickness")),
          ("pivot", args.double("pivot")),
          ("slotLength", args.double("slotLength")),
          ("slotWidth", args.double("slotWidth")),
        ]) {
        Ok(p) => p
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
  }
  let linkage = match family.build(parameters) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let component = if args.flag("noBase") {
    linkage
  } else {
    let length = parameters.get("length").unwrap_or(120.0)
    let width = parameters.get("width").unwrap_or(24.0)
    let thickness = parameters.get("thickness").unwrap_or(6.0)
    let pivot = parameters.get("pivot").unwrap_or(8.0)
    let base_thickness = args.double("baseThickness")
    let spacing = length - width
    let base_x = -length * 0.35
    let base_z = -base_thickness - 1.0
    let pin_length = thickness + base_thickness + 2.0
    linkage
    .add_layer(
      @cad.Cuboid::new(length * 0.7, width * 2.0, base_thickness),
      name="base-plate",
      color=@cad.Rgb::grey(),
      placement=@common.Placement::translation(base_x, -width, base_z),
    )
    .add_layer(
      @cad.Cylinder::new(pivot * 0.95, pin_length),
      name="pivot-pin-a",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(-spacing / 2.0, 0.0, base_z),
    )
    .add_layer(
      @cad.Cylinder::new(pivot * 0.95, pin_length),
      name="pivot-pin-b",
      color=@cad.Rgb::orange(),
      placement=@common.Placement::translation(spacing / 2.0, 0.0, base_z),
    )
  }
  if args.flag("evaluated") {
    component.write_step_evaluated(args.string_opt("out"))
    return
  }
  component.write_step(args.string_opt("out"), checked=true)
}
