///|
/// components/examples/tire_mount
///
/// Generate a parameterized tire mounting flange. The defaults are measured
/// from the owner-authored model in
/// `components/testdata/golden/external/tire-mount.step`.
///
/// ```bash
/// moon run components/examples/tire_mount -- -o /tmp/tire-mount.step
/// moon run components/examples/tire_mount -- \
///   --outer 86.3 --frontInner 51.85 --hubOuter 25.4 --bore 12.7 \
///   --plate 4 --ringDepth 19.05 --slotWidth 2 --slots 6 -o /tmp/mount.step
/// ```
async fn main {
  let base = @motion.tire_mount_spec()
  let spec = {
    "outer": @cli.opt_double(
      base.outer_diameter_mm,
      help="Outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "frontInner": @cli.opt_double(
      base.front_inner_diameter_mm,
      help="Front plate inner opening diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "hubOuter": @cli.opt_double(
      base.hub_outer_diameter_mm,
      help="Hub outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bore": @cli.opt_double(
      base.hub_bore_diameter_mm,
      help="Hub bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "plate": @cli.opt_double(
      base.plate_thickness_mm,
      help="Front plate thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "ringDepth": @cli.opt_double(
      base.ring_depth_mm,
      help="Rear ring depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "slotWidth": @cli.opt_double(
      base.slot_width_mm,
      help="Radial slot width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "slots": @cli.opt_int(base.slot_count, help="Number of radial slots", min=3),
    "slotPhase": @cli.opt_double(
      base.slot_phase_deg,
      help="First slot phase in degrees",
    ),
    "boltHoles": @cli.opt_int(
      base.bolt_hole_count,
      help="Number of bolt holes",
      min=1,
    ),
    "boltDiameter": @cli.opt_double(
      base.bolt_hole_diameter_mm,
      help="Bolt hole diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "boltCircle": @cli.opt_double(
      base.bolt_hole_circle_diameter_mm,
      help="Bolt hole circle diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "boltPhase": @cli.opt_double(
      base.bolt_hole_phase_deg,
      help="First bolt hole phase in degrees",
    ),
    "frontOffset": @cli.opt_double(
      base.front_offset_mm,
      help="Front face position on the X axis in mm",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "flat": @cli.flag(help="Write the nominal flat STEP instead of evaluating"),
    "bbox": @cli.flag(help="Print the mount bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/tire_mount",
      description="Generate a parameterized tire mounting flange.",
    )
    is Some(args) else {
    return
  }
  let measured : @motion.TireMountSpec = {
    outer_diameter_mm: args.double("outer"),
    front_inner_diameter_mm: args.double("frontInner"),
    hub_outer_diameter_mm: args.double("hubOuter"),
    hub_bore_diameter_mm: args.double("bore"),
    plate_thickness_mm: args.double("plate"),
    ring_depth_mm: args.double("ringDepth"),
    slot_width_mm: args.double("slotWidth"),
    slot_count: args.int("slots"),
    slot_phase_deg: args.double("slotPhase"),
    bolt_hole_count: args.int("boltHoles"),
    bolt_hole_diameter_mm: args.double("boltDiameter"),
    bolt_hole_circle_diameter_mm: args.double("boltCircle"),
    bolt_hole_phase_deg: args.double("boltPhase"),
    front_offset_mm: args.double("frontOffset"),
  }
  let mount = match @motion.tire_mount(measured) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = mount.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if args.flag("flat") {
    mount.write_step(args.string_opt("out"), checked=true)
  } else {
    mount.write_step_evaluated(args.string_opt("out"))
  }
}
