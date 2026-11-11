///|
/// components/examples/extrusion_frame
///
/// Generate a generic T-slot rectangular frame:
///
/// ```bash
/// moon run components/examples/extrusion_frame -- \
///   --width 400 --depth 300 --height 500 --series 2020 -o frame.step
/// ```
///
/// The profile is a generic engineering envelope, not a vendor-compatible
/// standard. Verify slot geometry against the intended manufacturer.
async fn main {
  let spec = {
    "width": @cli.opt_double(
      400.0,
      help="Frame width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "depth": @cli.opt_double(
      300.0,
      help="Frame depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      500.0,
      help="Frame height in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "series": @cli.opt_string(
      help="Generic series: 2020, 2040, 2060, 2080, 3030, 3060, 4040, 4080",
    ),
    "cornerRadius": @cli.opt_double(
      0.0,
      short='r',
      help="Outer section corner radius in mm (0 = sharp corners)",
      min=0.0,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "views": @cli.opt_string(
      help="Write top/front/side/isometric/section SVG diagnostics to this directory",
    ),
    "bbox": @cli.flag(help="Print the frame bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/extrusion_frame",
      description="Generate a generic T-slot rectangular frame.",
    )
    is Some(args) else {
    return
  }
  let base_profile = match
    parse_series(args.string_opt("series").unwrap_or("2020")) {
    Some(p) => p
    None => {
      @cli.eprintln(
        "error: unsupported series (use 2020, 2040, 2060, 2080, 3030, 3060, 4040, or 4080)",
      )
      abort("")
    }
  }
  let profile = match
    base_profile.with_corner_radius(args.double("cornerRadius")) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let width = args.double("width")
  let depth = args.double("depth")
  let height = args.double("height")
  let frame = match @assemblies.extrusion_frame(width, depth, height, profile) {
    Ok(a) => a
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = frame.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  match args.string_opt("views") {
    Some(dir) => {
      let schedule = match
        @assemblies.extrusion_frame_members(width, depth, height, profile) {
        Ok(m) => m
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      let pw = profile.width_mm
      let ph = profile.height_mm
      let members = schedule.map(fn(m) {
        let obb = @collision.Obb::from_placement(
          m.placement,
          (-pw / 2.0, pw / 2.0, -ph / 2.0, ph / 2.0, 0.0, m.cut_length_mm),
        )
        (m.id, m.cut_length_mm, obb)
      })
      let collisions : Array[String] = []
      for report in frame.collisions() {
        collisions.push(report.instance_a)
        collisions.push(report.instance_b)
      }
      @fs.mkdir(dir, recursive=true, allow_exist=true)
      for view in [Top, Front, Side, Iso] {
        let svg = frame_view_svg(
          members, collisions, view, width, depth, height,
        )
        @cad.write_text_file(svg, Some(dir + "/" + view.file_name()))
      }
      @cad.write_text_file(
        profile_section_svg(profile),
        Some(dir + "/frame-section.svg"),
      )
      @cli.eprintln(
        "wrote frame views (top/front/side/iso/section) to " +
        dir +
        " (" +
        collisions.length().to_string() +
        " collision endpoints highlighted)",
      )
    }
    None => ()
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => frame.write_assembly_step(out_path)
    "flat" => frame.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}

///|
fn parse_series(name : String) -> @profiles.TSlotProfile? {
  match name {
    "2020" => Some(@profiles.TSlotProfile::generic_2020())
    "2040" => Some(@profiles.TSlotProfile::generic_2040())
    "2060" => Some(@profiles.TSlotProfile::generic_2060())
    "2080" => Some(@profiles.TSlotProfile::generic_2080())
    "3030" => Some(@profiles.TSlotProfile::generic_3030())
    "3060" => Some(@profiles.TSlotProfile::generic_3060())
    "4040" => Some(@profiles.TSlotProfile::generic_4040())
    "4080" => Some(@profiles.TSlotProfile::generic_4080())
    _ => None
  }
}
