///|
/// components/examples/hiwin_guide
///
/// Generate a Hiwin HGR rail or HGH carriage with real counterbored mounting
/// holes and tapped bolt patterns.
///
/// ```bash
/// moon run components/examples/hiwin_guide -- --part rail15 --length 400 -o rail.step
/// moon run components/examples/hiwin_guide -- --part block20 -o block.step
/// ```
///
/// Both parts are written as OCCT-evaluated single solids (their counterbores
/// and carriage channel are real booleans).
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: rail15, rail20, block15, or block20",
    ),
    "length": @cli.opt_double(
      400.0,
      help="Rail length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/hiwin_guide",
      description="Generate a Hiwin HGR rail or HGH carriage.",
    )
    is Some(args) else {
    return
  }
  let kind = args.string_opt("part").unwrap_or("rail15")
  let length = args.double("length")
  let result : Result[@common.Component, @common.SpecError] = match kind {
    "rail15" => @mechanisms.hiwin_hgr_rail(size="HGR15", length_mm=length)
    "rail20" => @mechanisms.hiwin_hgr_rail(size="HGR20", length_mm=length)
    "block15" => @mechanisms.hiwin_hgh_block(size="HGH15CA")
    "block20" => @mechanisms.hiwin_hgh_block(size="HGH20CA")
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
  // Rails and carriages are layered/boolean solids; the flat writer is nominal,
  // so the accepted artifact is always the OCCT-evaluated one.
  component.write_step_evaluated(args.string_opt("out"))
}
