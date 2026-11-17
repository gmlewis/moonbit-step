///|
/// components/examples/makerpipe_kit
///
/// Generate Maker Pipe-compatible structural EMT connectors and accessories:
///
/// ```bash
/// moon run components/examples/makerpipe_kit -- --part tee --size 3/4 -o /tmp/tee.step
/// moon run components/examples/makerpipe_kit -- --part elbow --size 3/4 --angle 90 -o /tmp/e90.step
/// moon run components/examples/makerpipe_kit -- --part saddle --size 3/4 --branches 0,90,180 -o /tmp/fourway.step
/// moon run components/examples/makerpipe_kit -- --part coupling --size 3/4 -o /tmp/coupling.step
/// moon run components/examples/makerpipe_kit -- --part flange --size 3/4 -o /tmp/flange.step
/// moon run components/examples/makerpipe_kit -- --part adj-hinge --size 3/4 --angle 30 -o /tmp/adj-hinge.step
/// moon run components/examples/makerpipe_kit -- --part top-rail-tee -o /tmp/top-rail-tee.step
/// moon run components/examples/makerpipe_kit -- --part shim --from 3/4 --to 1 -o /tmp/shim.step
/// moon run components/examples/makerpipe_kit -- --part foot --trade 1/2 -o /tmp/foot.step
/// moon run components/examples/makerpipe_kit -- --part strap-1 --trade 3/4 -o /tmp/strap.step
/// ```
async fn required_size(name : String) -> @makerpipe.MakerPipeSize {
  match @makerpipe.makerpipe_size(name) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
}

///|
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: tee (default), elbow, saddle, coupling, flange, adj-hinge, adj-180, adj-flange, top-rail-tee, shim, end-cap, foot, insert, strap-1, strap-2, mounting-strap, cross-over, telescoping, barrel-hinge, printed-hinge, clip, friction-band, elbow-45, elbow-90, elbow-135, straight-180, four-way, five-way",
    ),
    "size": @cli.opt_string(help="Native connector size: 3/4 (default) or 1"),
    "trade": @cli.opt_string(
      help="EMT trade size for accessories: 1/2, 3/4 (default), 1",
    ),
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
    "from": @cli.opt_string(
      help="Shim inside pipe trade size: 1/2 or 3/4 (default 3/4)",
    ),
    "to": @cli.opt_string(
      help="Shim outside connector size: 3/4 or 1 (default 1)",
    ),
    "thread": @cli.opt_string(
      help="Pipe-insert thread: 1/4-20 (default) or 3/8-16",
    ),
    "no-lip": @cli.flag(help="Omit the threaded-insert lip"),
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
      description="Generate Maker Pipe-compatible structural EMT connectors and accessories.",
    )
    is Some(args) else {
    return
  }
  let size_name = args.string_opt("size").unwrap_or("3/4")
  let trade = args.string_opt("trade").unwrap_or(size_name)
  let part_name = args.string_opt("part").unwrap_or("tee")
  let component = match part_name {
    "tee" => @makerpipe.tee(required_size(size_name))
    "elbow" => @makerpipe.elbow(required_size(size_name), args.double("angle"))
    "elbow-45" => @makerpipe.elbow_45(required_size(size_name))
    "elbow-90" => @makerpipe.elbow_90(required_size(size_name))
    "elbow-135" => @makerpipe.elbow_135(required_size(size_name))
    "straight-180" => @makerpipe.straight_180(required_size(size_name))
    "four-way" => @makerpipe.four_way(required_size(size_name))
    "five-way" => @makerpipe.five_way(required_size(size_name))
    "coupling" =>
      @makerpipe.coupling(
        required_size(size_name),
        length_mm=args.double("length"),
      )
    "flange" =>
      @makerpipe.flange(
        required_size(size_name),
        base_diameter_mm=args.double("baseDiameter"),
        base_thickness_mm=args.double("baseThickness"),
        bolt_circle_mm=args.double("boltCircle"),
        bolt_hole_mm=args.double("boltHole"),
        socket_depth_mm=args.double("socketDepth"),
      )
    "adj-hinge" =>
      @makerpipe.adjustable_hinge(
        required_size(size_name),
        args.double("angle"),
      )
    "adj-180" =>
      @makerpipe.adjustable_180(
        required_size(size_name),
        args.double("angle"),
        args.double("angle2"),
      )
    "adj-flange" =>
      @makerpipe.adjustable_flange(
        required_size(size_name),
        args.double("angle"),
        base_diameter_mm=args.double("baseDiameter"),
        base_thickness_mm=args.double("baseThickness"),
        bolt_circle_mm=args.double("boltCircle"),
        bolt_hole_mm=args.double("boltHole"),
      )
    "top-rail-tee" => @makerpipe.top_rail_tee()
    "shim" =>
      @makerpipe.adapter_shim(
        args.string_opt("from").unwrap_or("3/4"),
        args.string_opt("to").unwrap_or("1"),
      )
    "end-cap" => @makerpipe.end_cap(trade)
    "foot" => @makerpipe.rubber_foot(trade)
    "insert" =>
      @makerpipe.threaded_insert(
        trade,
        args.string_opt("thread").unwrap_or("1/4-20"),
        lip=if args.flag("no-lip") { false } else { true },
      )
    "strap-1" => @makerpipe.one_hole_strap(trade)
    "strap-2" => @makerpipe.two_hole_strap(trade)
    "mounting-strap" => @makerpipe.mounting_strap(trade)
    "cross-over" => @makerpipe.cross_over_clamp(trade)
    "telescoping" => @makerpipe.telescoping_clamp()
    "barrel-hinge" => @makerpipe.barrel_hinge()
    "printed-hinge" => @makerpipe.printed_hinge(trade)
    "clip" => @makerpipe.pipe_clip(trade)
    "friction-band" => @makerpipe.friction_band(trade)
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
      @makerpipe.saddle_connector(required_size(size_name), angles)
    }
    other => {
      @cli.eprintln(
        "error: unknown part '\{other}'; use tee, elbow, saddle, coupling, flange, adj-hinge, adj-180, adj-flange, top-rail-tee, shim, end-cap, foot, insert, strap-1, strap-2, mounting-strap, cross-over, telescoping, barrel-hinge, printed-hinge, clip, friction-band, elbow-45, elbow-90, elbow-135, straight-180, four-way, or five-way",
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
