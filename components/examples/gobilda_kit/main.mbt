///|
/// components/examples/gobilda_kit
///
/// Generate a goBILDA® part: a grid plate or a 1120-series U-channel.
///
/// ```bash
/// # 5 x 5 grid plate (40 x 40 x 2.5 mm)
/// moon run components/examples/gobilda_kit -- -o gobilda-grid-5x5.step
///
/// # 11 x 29 grid plate (88 x 232 mm), an 1116 Series bundle size
/// moon run components/examples/gobilda_kit -- --cols 11 --rows 29 -o big.step
///
/// # 8-hole U-channel (48 x 48 x 216 mm)
/// moon run components/examples/gobilda_kit -- --part channel -o u.step
/// ```
///
/// A plate named `cols x rows` is `cols * 8` by `rows * 8` mm with a 4 mm edge
/// margin around the hole grid; a channel's length is `(holes + 1) * 24` mm.
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: plate (default), channel, beam, or hub",
    ),
    "cols": @cli.opt_int(5, help="Hole columns along X (plate)"),
    "rows": @cli.opt_int(5, help="Hole rows along Y (plate)"),
    "holes": @cli.opt_int(8, help="Bearing-hole count (channel)"),
    "beamHoles": @cli.opt_int(4, help="Hole count (beam)"),
    "thickness": @cli.opt_double(
      2.5,
      short='t',
      help="Plate or wall thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "evaluated": @cli.flag(
      help="Write the OCCT-evaluated single solid (the channel's fused U-section)",
    ),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/gobilda_kit",
      description="Generate a goBILDA grid plate or U-channel.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("plate")
  let component = match part_kind {
    "plate" =>
      match
        @gobilda.gobilda_grid_plate(
          cols=args.int("cols"),
          rows=args.int("rows"),
          thickness_mm=args.double("thickness"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "channel" =>
      match
        @gobilda.gobilda_u_channel(
          holes=args.int("holes"),
          thickness_mm=args.double("thickness"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "beam" =>
      match @gobilda.gobilda_square_beam(holes=args.int("beamHoles")) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "hub" =>
      match @gobilda.gobilda_sonic_hub() {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    other => {
      @cli.eprintln("error: unknown part: " + other)
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if args.flag("evaluated") {
    component.write_step_evaluated(args.string_opt("out"))
  } else {
    component.write_step(args.string_opt("out"), checked=true)
  }
}
