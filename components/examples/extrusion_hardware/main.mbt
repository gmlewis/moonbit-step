///|
/// components/examples/extrusion_hardware
///
/// Generate an extrusion T-nut or a heat-set threaded insert:
///
/// ```bash
/// moon run components/examples/extrusion_hardware -- \
///   --part tnut --thread M3 --slot 5 -o tnut-m3.step
/// moon run components/examples/extrusion_hardware -- \
///   --part heat-set --thread M3 --length long -o heatset-m3-long.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(short='p', help="Part: tnut (default) or heat-set"),
    "thread": @cli.opt_string(short='t', help="Thread: M3 (default), M4, M5"),
    "slot": @cli.opt_double(
      5.0,
      short='s',
      help="Extrusion slot width in mm for a T-nut",
      min=0.0,
      min_exclusive=true,
    ),
    "length": @cli.opt_string(
      short='l',
      help="Heat-set insert length: short (default) or long",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/extrusion_hardware",
      description="Generate an extrusion T-nut or a heat-set insert.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("tnut")
  let thread = args.string_opt("thread").unwrap_or("M3")
  let component = match part_kind {
    "heat-set" | "heatset" | "insert" =>
      match
        @fasteners.heat_set_insert_m3(
          args.string_opt("length").unwrap_or("short"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    _ => {
      let tnut_spec = match
        @fasteners.extrusion_tnut_spec(
          thread,
          slot_width_mm=args.double("slot"),
        ) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match @fasteners.extrusion_tnut(tnut_spec) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
