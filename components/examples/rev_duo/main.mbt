///|
/// components/examples/rev_duo
///
/// Generate a REV Robotics DUO 15 mm extrusion or 45 mm U-channel with the
/// measured sections.
///
/// ```bash
/// moon run components/examples/rev_duo -- --part extrusion15 --length 120 -o rev-15mm-120.step
/// moon run components/examples/rev_duo -- --part uchannel45 --length 440 -o rev-45mm-440.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: extrusion15 (default) or uchannel45",
    ),
    "length": @cli.opt_double(
      120.0,
      help="Length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/rev_duo",
      description="Generate a REV DUO 15 mm extrusion or 45 mm U-channel.",
    )
    is Some(args) else {
    return
  }
  let length = args.double("length")
  let result : Result[@common.Component, @common.SpecError] = match
    args.string_opt("part").unwrap_or("extrusion15") {
    "extrusion15" => @profiles.rev_15mm_extrusion(length_mm=length)
    "uchannel45" => @profiles.rev_45mm_uchannel(length_mm=length)
    other => {
      @cli.eprintln("error: unknown part: " + other)
      abort("")
    }
  }
  let component = match result {
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
