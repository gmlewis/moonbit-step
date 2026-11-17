///|
/// components/examples/makerpipe_kit
///
/// Generate Maker Pipe-compatible structural EMT connectors:
///
/// ```bash
/// moon run components/examples/makerpipe_kit -- --part tee --size 3/4 -o /tmp/tee.step
/// moon run components/examples/makerpipe_kit -- --part elbow --size 3/4 --angle 90 -o /tmp/e90.step
/// moon run components/examples/makerpipe_kit -- --part saddle --size 3/4 --branches 0,90,180 -o /tmp/fourway.step
/// moon run components/examples/makerpipe_kit -- --part coupling --size 3/4 -o /tmp/coupling.step
/// moon run components/examples/makerpipe_kit -- --part flange --size 3/4 -o /tmp/flange.step
/// moon run components/examples/makerpipe_kit -- --part adj-hinge --size 3/4 --angle 30 -o /tmp/adj-hinge.step
/// moon run components/examples/makerpipe_kit -- --part top-rail-tee -o /tmp/top-rail-tee.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: tee (default), elbow, saddle, coupling, flange, adj-hinge, adj-180, adj-flange, top-rail-tee, elbow-45, elbow-90, elbow-135, straight-180, four-way, five-way",
    ),
    "size": @cli.opt_string(help="Native size: 3/4 (default) or 1"),
    "angle": @cli.opt_double(
      90.0,
      help="Elbow or adjustable fitting angle in degrees",
    ),
    "angle2": @cli.opt_double(0.0, help="Second end-clamp angle for adj-180"),
    "branches": @cli.opt_string(
      help="Comma-separated branch angles in degrees (saddle part)",
    ),
    "length": @cli.opt_double(
      0.0,
      help="Coupling length in mm (0 = 2x T socket depth)",
    ),
    "baseDiameter": @cli.opt_double(70.0, help="Flange base diameter in mm"),
    "baseThickness": @cli.opt_double(5.0, help="Flange base thickness in mm"),
    "boltCircle": @cli.opt_double(
      54.0,
      help="Flange mounting bolt circle in mm",
    ),
    "boltHole": @cli.opt_double(6.6, help="Flange mounting hole diameter in mm"),
    "socketDepth": @cli.opt_double(
      0.0,
      help="Flange socket depth in mm (0 = default)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
    "evaluated": @cli.flag(
      help="Fuse the layers with OCCT and write one trimmed solid",
    ),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/makerpipe_kit",
      description="Generate Maker Pipe-compatible structural EMT connectors.",
    )
    is Some(args) else {
    return
  }
  let size_name = args.string_opt("size").unwrap_or("3/4")
  let size = match @makerpipe.makerpipe_size(size_name) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let part_name = args.string_opt("part").unwrap_or("tee")
  let component = match part_name {
    "tee" => @makerpipe.tee(size)
    "elbow" => @makerpipe.elbow(size, args.double("angle"))
    "elbow-45" => @makerpipe.elbow_45(size)
    "elbow-90" => @makerpipe.elbow_90(size)
    "elbow-135" => @makerpipe.elbow_135(size)
    "straight-180" => @makerpipe.straight_180(size)
    "four-way" => @makerpipe.four_way(size)
    "five-way" => @makerpipe.five_way(size)
    "coupling" => @makerpipe.coupling(size, length_mm=args.double("length"))
    "flange" =>
      @makerpipe.flange(
        size,
        base_diameter_mm=args.double("baseDiameter"),
        base_thickness_mm=args.double("baseThickness"),
        bolt_circle_mm=args.double("boltCircle"),
        bolt_hole_mm=args.double("boltHole"),
        socket_depth_mm=args.double("socketDepth"),
      )
    "adj-hinge" => @makerpipe.adjustable_hinge(size, args.double("angle"))
    "adj-180" =>
      @makerpipe.adjustable_180(
        size,
        args.double("angle"),
        args.double("angle2"),
      )
    "adj-flange" =>
      @makerpipe.adjustable_flange(
        size,
        args.double("angle"),
        base_diameter_mm=args.double("baseDiameter"),
        base_thickness_mm=args.double("baseThickness"),
        bolt_circle_mm=args.double("boltCircle"),
        bolt_hole_mm=args.double("boltHole"),
      )
    "top-rail-tee" => @makerpipe.top_rail_tee()
    "saddle" => {
      let text = args.string_opt("branches").unwrap_or("0,90")
      let angles : Array[Double] = []
      for piece in text.split(",").collect() {
        let token = piece.trim().to_owned()
        if token.length() > 0 {
          let angle = @string.parse_double(token) catch {
            _ => {
              @cli.eprintln(
                "error: invalid branch angle '\{token}' in --branches",
              )
              abort("")
            }
          }
          angles.push(angle)
        }
      }
      @makerpipe.saddle_connector(size, angles)
    }
    other => {
      @cli.eprintln(
        "error: unknown part '\{other}'; use tee, elbow, saddle, coupling, flange, adj-hinge, adj-180, adj-flange, top-rail-tee, elbow-45, elbow-90, elbow-135, straight-180, four-way, or five-way",
      )
      abort("")
    }
  }
  let part = match component {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if args.flag("evaluated") {
    part.write_step_evaluated(args.string_opt("out"))
  } else {
    part.write_step(args.string_opt("out"), checked=true)
  }
}
