///|
/// components/examples/set_screw_collar
///
/// Generate a set-screw shaft collar whose radial set-screw hole is real
/// trimmed geometry. The output is the OCCT-evaluated single solid, because the
/// kernel-free flat writer cannot trim a radial hole.
///
/// ```bash
/// moon run components/examples/set_screw_collar -- \
///   --bore 8 --outer 16 --width 8 --thread M5 -o set-screw-collar.step
/// ```
///
/// `--drill 0` (the default) uses the ISO metric internal minor diameter (tap
/// drill) of `--thread`. Pass a positive diameter to reproduce a measured
/// reference hole. Threads are declared by a connector, never modelled.
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
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/set_screw_collar",
      description="Generate a set-screw shaft collar with a real radial hole.",
    )
    is Some(args) else {
    return
  }
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
  let component = match
    @motion.set_screw_shaft_collar(
      args.double("bore"),
      args.double("outer"),
      args.double("width"),
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
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step_evaluated(args.string_opt("out"))
}
