///|
/// components/examples/pvc
///
/// Generate Schedule 40 / Schedule 80 IPS PVC pipe, socket fittings, and
/// complete prototype box frames:
///
/// ```bash
/// moon run components/examples/pvc -- --part pipe --size 3/4 --length 300 -o /tmp/pipe.step
/// moon run components/examples/pvc -- --part elbow-90 --size 3/4 --evaluated -o /tmp/elbow90.step
/// moon run components/examples/pvc -- --part corner-3way --size 1/2 --evaluated -o /tmp/corner.step
/// moon run components/examples/pvc -- --part tee --size 3/4 --evaluated -o /tmp/tee.step
/// moon run components/examples/pvc -- --part reducer --size 1 --toSize 3/4 -o /tmp/reducer.step
/// moon run components/examples/pvc -- --part flange --size 3/4 --evaluated -o /tmp/flange.step
/// moon run components/examples/pvc -- --part box-frame --size 1/2 --width 400 --depth 300 --height 250 -o /tmp/frame.step
/// ```
async fn parse_schedule(text : String) -> @pvclib.PvcSchedule {
  match text.to_lower() {
    "" | "40" | "sch40" | "schedule40" => Schedule40
    "80" | "sch80" | "schedule80" => Schedule80
    other => {
      @cli.eprintln("error: unknown PVC schedule '\{other}' (use 40 or 80)")
      abort("")
    }
  }
}

///|
async fn parse_detail(text : String) -> @common.DetailLevel {
  match text.to_lower() {
    "" | "simplified" => Simplified
    "detailed" => Detailed
    "full" | "fully-modeled" | "fully_modeled" => FullyModeled
    other => {
      @cli.eprintln(
        "error: unknown detail level '\{other}' (use simplified, detailed, or full)",
      )
      abort("")
    }
  }
}

///|
async fn require_pvc_size(
  trade : String,
  schedule : @pvclib.PvcSchedule,
  clearance : Double,
) -> @pvclib.PvcSize {
  match @pvclib.pvc_size(trade, schedule~, bore_clearance_mm=clearance) {
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
      help="Part: elbow-90 (default), pipe, coupling, cap, reducer, elbow-45, tee, cross, corner-3way, four-way, five-way, flange, box-frame",
    ),
    "size": @cli.opt_string(
      help="IPS PVC trade size: 1/2, 3/4 (default), 1, 1-1/4, 1-1/2, 2",
    ),
    "toSize": @cli.opt_string(
      help="Small IPS size for reducer coupling (default 1/2)",
    ),
    "schedule": @cli.opt_string(help="PVC schedule: 40 (default) or 80"),
    "clearance": @cli.opt_double(
      @pvclib.pvc_default_bore_clearance_mm,
      help="Socket bore slip clearance over pipe OD in mm (default 0.25)",
      min=0.0,
    ),
    "length": @cli.opt_double(304.8, help="Pipe length in mm", min=0.0),
    "stopLength": @cli.opt_double(
      4.0,
      help="Coupling center pipe-stop width in mm",
      min=0.0,
    ),
    "baseDiameter": @cli.opt_double(
      0.0,
      help="Flange base OD in mm (0 = automatic)",
      min=0.0,
    ),
    "baseThickness": @cli.opt_double(
      6.0,
      help="Flange base thickness in mm",
      min=0.0,
    ),
    "boltCircle": @cli.opt_double(
      0.0,
      help="Flange bolt circle diameter in mm (0 = automatic)",
      min=0.0,
    ),
    "boltHole": @cli.opt_double(
      5.5,
      help="Flange mounting bolt hole diameter in mm",
      min=0.0,
    ),
    "width": @cli.opt_double(
      400.0,
      help="Box-frame centerline width in mm",
      min=0.0,
    ),
    "depth": @cli.opt_double(
      300.0,
      help="Box-frame centerline depth in mm",
      min=0.0,
    ),
    "height": @cli.opt_double(
      250.0,
      help="Box-frame centerline height in mm",
      min=0.0,
    ),
    "detail": @cli.opt_string(
      help="Detail level: simplified (default), detailed, full",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
    "evaluated": @cli.flag(
      help="Fuse layers with OCCT and write one trimmed solid",
    ),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/pvc",
      description="Generate ASTM D1785/D2466 PVC pipe, fittings, and prototype box frames as STEP",
    )
    is Some(args) else {
    return
  }
  let part_name = args.string_opt("part").unwrap_or("elbow-90").to_lower()
  let size_name = args.string_opt("size").unwrap_or("3/4")
  let to_size_name = args.string_opt("toSize").unwrap_or("1/2")
  let schedule = parse_schedule(args.string_opt("schedule").unwrap_or(""))
  let detail = parse_detail(args.string_opt("detail").unwrap_or(""))
  let clearance = args.double("clearance")
  let size = require_pvc_size(size_name, schedule, clearance)
  let result : Result[@common.Component, @common.SpecError] = match part_name {
    "pipe" => @pvclib.pvc_pipe(size, args.double("length"), detail~)
    "coupling" =>
      @pvclib.coupling(size, stop_length_mm=args.double("stopLength"), detail~)
    "cap" => @pvclib.cap(size, detail~)
    "reducer" | "reducer-coupling" => {
      let small = require_pvc_size(to_size_name, schedule, clearance)
      @pvclib.reducer_coupling(size, small, detail~)
    }
    "elbow-90" | "elbow90" => @pvclib.elbow_90(size, detail~)
    "elbow-45" | "elbow45" => @pvclib.elbow_45(size, detail~)
    "tee" => @pvclib.tee(size, detail~)
    "cross" => @pvclib.cross(size, detail~)
    "corner-3way" | "3way" => @pvclib.corner_3way(size, detail~)
    "four-way" | "4way" | "four-way-tee" => @pvclib.four_way_tee(size, detail~)
    "five-way" | "5way" => @pvclib.five_way(size, detail~)
    "flange" =>
      @pvclib.flange(
        size,
        base_diameter_mm=args.double("baseDiameter"),
        base_thickness_mm=args.double("baseThickness"),
        bolt_circle_mm=args.double("boltCircle"),
        bolt_hole_mm=args.double("boltHole"),
        detail~,
      )
    "box-frame" | "frame" =>
      @pvclib.pvc_box_frame_assembly(
        args.double("width"),
        args.double("depth"),
        args.double("height"),
        size,
        detail~,
      )
    other => {
      @cli.eprintln(
        "error: unknown part '\{other}' (use pipe, coupling, cap, reducer, elbow-90, elbow-45, tee, cross, corner-3way, four-way, five-way, flange, box-frame)",
      )
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
  if args.flag("evaluated") {
    component.write_step_evaluated(args.string_opt("out"))
  } else {
    component.write_step(args.string_opt("out"), checked=true)
  }
}
