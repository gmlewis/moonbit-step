///|
/// components/examples/set_screw_collar
///
/// Generate a set-screw shaft collar whose radial set-screw hole is real
/// trimmed geometry, with a DIN 916 plain-envelope set screw placed in it. The
/// output is the OCCT-evaluated compound, because the kernel-free flat writer
/// cannot trim a radial hole.
///
/// ```bash
/// moon run components/examples/set_screw_collar -- \
///   --bore 8 --outer 16 --width 8 --thread M5 -o set-screw-collar.step
/// ```
///
/// `--drill 0` (the default) uses the ISO metric internal minor diameter (tap
/// drill) of `--thread`. Pass a positive diameter to reproduce a measured
/// reference hole. The set screw is a DIN 916 envelope at its nominal diameter,
/// so it must be smaller than the modeled hole; it is omitted with `--noScrew`.
/// Threads are declared by connectors, never modelled.

///|
/// Screw tip inset from the bore surface: enough to keep the plain envelope
/// disjoint from the collar after the boolean union.
const SCREW_TIP_INSET_MM : Double = 0.05

///|
async fn main {
  let spec = {
    "bore": @cli.opt_double(
      8.0,
      help="Shaft bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "outer": @cli.opt_double(
      16.0,
      help="Outside diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      8.0,
      help="Collar width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thread": @cli.opt_string(
      help="ISO metric set-screw thread designation (e.g. M4, M5)",
    ),
    "drill": @cli.opt_double(
      0.0,
      help="Radial hole diameter in mm; 0 uses the thread's ISO tap drill",
      min=0.0,
    ),
    "chamfer": @cli.opt_double(0.2, help="45 degree rim chamfer in mm", min=0.0),
    "screw": @cli.opt_string(
      help="DIN 916 set-screw size to place (default M4)",
    ),
    "screwLength": @cli.opt_double(
      4.0,
      help="DIN 916 set-screw length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "noScrew": @cli.flag(help="Omit the set screw and export the collar only"),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/set_screw_collar",
      description="Generate a set-screw shaft collar with a real radial hole and set screw.",
    )
    is Some(args) else {
    return
  }
  let bore = args.double("bore")
  let outer = args.double("outer")
  let width = args.double("width")
  let thread_text = match args.string_opt("thread") {
    Some(text) => text
    None => "M5"
  }
  let thread = match @standards.MetricSize::parse(thread_text) {
    Some(size) => size
    None => {
      @cli.eprintln(
        "error: unknown ISO metric thread designation: " + thread_text,
      )
      abort("")
    }
  }
  let drill_arg = args.double("drill")
  let drill = if drill_arg > 0.0 {
    drill_arg
  } else {
    @standards.ThreadSpec::coarse(thread).internal_minor_diameter_mm()
  }
  let collar = match
    @motion.set_screw_shaft_collar(
      bore,
      outer,
      width,
      thread~,
      drill_diameter_mm=drill,
      chamfer_mm=args.double("chamfer"),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let mut component = collar
  if !args.flag("noScrew") {
    let screw_text = match args.string_opt("screw") {
      Some(text) => text
      None => "M4"
    }
    let screw_size = match @standards.MetricSize::parse(screw_text) {
      Some(size) => size
      None => {
        @cli.eprintln(
          "error: unknown ISO metric set-screw designation: " + screw_text,
        )
        abort("")
      }
    }
    let screw_diameter = screw_size.nominal_diameter_mm()
    if screw_diameter >= drill {
      @cli.eprintln(
        "error: set screw \{screw_size.designation()} (\{screw_diameter} mm) does not fit the modeled \{drill} mm hole",
      )
      abort("")
    }
    let screw_length = args.double("screwLength")
    let screw = match
      @fasteners.din916_cup_point_set_screw(screw_size, screw_length) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    // DIN 916: point at z = 0, socket at z = length. Rotate +Z to +Y so the
    // point enters the collar from +Y, then centre it on the radial hole.
    let tip_y = bore / 2.0 - SCREW_TIP_INSET_MM
    let placed = screw.rotate_x(-90.0).translate(y=tip_y, z=width / 2.0)
    let mut index = 0
    for layer in placed.layers() {
      component = component.add_layer(
        layer.shape,
        name="set-screw-\{index}",
        color=@cad.Rgb::grey(),
        placement=layer.placement,
      )
      index = index + 1
    }
    for connector in placed.connectors() {
      component = component.with_connector_unchecked(connector)
    }
    let features = @common.FeatureRecord::new(
      modeled=[
        "collar", "outside-cylinder", "bore", "rim-chamfers", "set-screw-hole", "set-screw-envelope",
        "set-screw-hex-socket", "set-screw-cup-point",
      ],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="set-screw-thread",
          reason="the thread interface is declared by the set-screw-thread and set-screw point connectors, not modelled",
        ),
        @common.Omission::new(
          feature="holding-torque-and-material",
          reason="nominal geometry only; no holding torque, material, or strength claim",
        ),
      ],
    )
    let metadata = @common.Metadata::new(
      designation="Set-screw shaft collar \{@cad.fmt_double(bore, None)} bore x \{@cad.fmt_double(outer, None)} OD x \{@cad.fmt_double(width, None)} with DIN 916 \{screw_size.designation()} x \{@cad.fmt_double(screw_length, None)} set screw",
      standard="DIN 916 (set screw); ISO 261 / ISO 68-1 (thread interface)",
      family="set-screw shaft collar assembly",
      size="\{@cad.fmt_double(bore, None)}x\{@cad.fmt_double(outer, None)}x\{@cad.fmt_double(width, None)}-\{screw_size.designation()}x\{@cad.fmt_double(screw_length, None)}",
      length_mm=screw_length,
      source="Parametric collar with a trimmed radial hole plus a DIN 916 plain-envelope set screw; threads are declared, not modelled.",
    )
    component = component
      .with_metadata(metadata)
      .with_description(
        "Set-screw shaft collar with a DIN 916 plain-envelope set screw in the radial hole. The collar hole is OCCT-trimmed; the set-screw thread is declared by connectors and not modelled.",
      )
      .with_features(features)
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step_evaluated(args.string_opt("out"))
}
