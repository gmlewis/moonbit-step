///|
// 03-engraved-name-tag
//
// A working example that generates a STEP model for a keychain tag with
// programmable text placement and border styles.
//
// Usage (stdout):
//   moon run --target native examples/03-engraved-name-tag -- --name Susan > name-tag.step
//
// Usage (write file):
//   moon run --target native examples/03-engraved-name-tag -- --name Susan -o name-tag.step
//

///|
fn dist2(a : (Double, Double), b : (Double, Double)) -> Double {
  let (ax, ay) = a
  let (bx, by) = b
  @draw.Vec2::distance_squared(@draw.vec2(ax, ay), @draw.vec2(bx, by))
}

///|
fn dedupe_consecutive(
  pts_in : Array[(Double, Double)],
) -> Array[(Double, Double)] {
  // NOTE: This epsilon is compared against dist2 (squared distance).
  // Keeping the existing semantics/threshold to avoid changing behavior.
  let eps2 : Double = 0.000000001
  if pts_in.length() == 0 {
    return []
  }
  let out : Array[(Double, Double)] = []
  out.push(pts_in[0])
  for i = 1; i < pts_in.length(); i = i + 1 {
    if dist2(out[out.length() - 1], pts_in[i]) > eps2 {
      out.push(pts_in[i])
    }
  }
  out
}

///|
fn cubic_at(
  p0 : (Double, Double),
  p1 : (Double, Double),
  p2 : (Double, Double),
  p3 : (Double, Double),
  t : Double,
) -> (Double, Double) {
  let (x0, y0) = p0
  let (x1, y1) = p1
  let (x2, y2) = p2
  let (x3, y3) = p3
  let s = 1.0 - t
  let s2 = s * s
  let t2 = t * t
  let b0 = s2 * s
  let b1 = 3.0 * s2 * t
  let b2 = 3.0 * s * t2
  let b3 = t2 * t
  (b0 * x0 + b1 * x1 + b2 * x2 + b3 * x3, b0 * y0 + b1 * y1 + b2 * y2 + b3 * y3)
}

///|
fn path_to_polygon(
  path : @draw.Path,
  curve_segments : Int,
) -> Array[(Double, Double)] {
  // Returns [] for non-closed paths.
  if !path.closed {
    return []
  }
  let anchors = path.anchors
  let n = anchors.length()
  if n < 2 {
    return []
  }
  let segs = if curve_segments <= 1 { 1 } else { curve_segments }
  let pts : Array[(Double, Double)] = []
  let a0 = anchors[0]
  pts.push((a0.position.x, a0.position.y))
  let emit_segment = fn(a : @draw.Anchor, b : @draw.Anchor) -> Unit {
    let p0 = (a.position.x, a.position.y)
    let p1 = (a.position.x + a.handle_out.x, a.position.y + a.handle_out.y)
    let p2 = (b.position.x + b.handle_in.x, b.position.y + b.handle_in.y)
    let p3 = (b.position.x, b.position.y)
    // If both handles are zero vectors, this is a straight line.
    let is_line = (a.handle_out.x == 0.0 && a.handle_out.y == 0.0) &&
      b.handle_in.x == 0.0 &&
      b.handle_in.y == 0.0
    if is_line {
      pts.push(p3)
    } else {
      for si = 1; si <= segs; si = si + 1 {
        let t = Double::from_int(si) / Double::from_int(segs)
        pts.push(cubic_at(p0, p1, p2, p3, t))
      }
    }
  }
  for i = 1; i < n; i = i + 1 {
    emit_segment(anchors[i - 1], anchors[i])
  }
  emit_segment(anchors[n - 1], anchors[0])
  let pts = dedupe_consecutive(pts)
  if pts.length() >= 2 && dist2(pts[0], pts[pts.length() - 1]) <= 0.000000001 {
    ignore(pts.pop())
  }
  pts
}

///|
fn graphic_to_profiles(
  g : @draw.Graphic,
  curve_segments : Int,
) -> Array[(Array[(Double, Double)], Array[Array[(Double, Double)]])] {
  match g {
    @draw.Graphic::Path(path) => {
      let outer = path_to_polygon(path, curve_segments)
      if outer.length() >= 3 {
        [(outer, [])]
      } else {
        []
      }
    }
    @draw.Graphic::CompoundPath(cp) =>
      if cp.paths.length() == 0 {
        []
      } else {
        let outer = path_to_polygon(cp.paths[0], curve_segments)
        if outer.length() < 3 {
          []
        } else {
          let holes : Array[Array[(Double, Double)]] = []
          for i = 1; i < cp.paths.length(); i = i + 1 {
            let hole = path_to_polygon(cp.paths[i], curve_segments)
            if hole.length() >= 3 {
              holes.push(hole)
            }
          }
          [(outer, holes)]
        }
      }
    _ => []
  }
}

///|
async fn main {
  let base_args_spec = {
    "debug": @cli.flag(short='d', help="Print debug information"),
    "length": @cli.opt_double(
      50.0,
      help="Tag length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      20.0,
      help="Tag width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      12.0,
      help="Tag height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "margin": @cli.opt_double(3.0, help="Font margin (mm)"),
    "embossDepth": @cli.opt_double(
      1.0,
      help="Text emboss height above the tag top (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "curveSegments": @cli.opt_double(
      12.0,
      help="Polyline segments per cubic curve (higher = smoother)",
      min=1.0,
      min_exclusive=false,
    ),
    // "filletRadius": @cli.opt_double(
    //   0.0,
    //   help="Top-edge fillet radius (mm). When > 0, takes precedence over chamfer.",
    //   min=0.0,
    // ),
    "name": @cli.opt_string(short='n', help="Name to engrave on the tag"),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="03-engraved-name-tag",
      description="Generate a keychain tag STEP model.",
    )
    is Some(args) else {
    return
  }
  let debug = args.flag("debug")
  let length_mm = args.double("length")
  let width_mm = args.double("width")
  let height_mm = args.double("height")
  let margin_mm = args.double("margin")
  let emboss_depth_mm = args.double("embossDepth")
  let curve_segments = {
    let v = args.double("curveSegments").to_int()
    if v < 1 {
      1
    } else {
      v
    }
  }
  // let fillet_radius_mm = args.double("filletRadius")
  guard args.string_opt("name") is Some(name) else {
    println("--name is required")
    return
  }
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => return
  }
  let font = @baloo.font
  let out_path = args.string_opt("out")

  //
  let bbox = @draw.bbox(
    margin_mm,
    margin_mm,
    length_mm - margin_mm,
    width_mm - margin_mm,
  )

  // Handle the error-throwing function call
  let text_raw = @draw.text(text=name, font~, align=Center).transform(
    scale=@draw.vec2(1, -1),
  ) catch {
    e => {
      println("Error creating text: \{e}")
      return
    }
  }
  let text = text_raw.fit_to(bbox)
  let all_paths = text.all_paths_and_compound_paths()
  if debug {
    println(
      "Generated tag dimensions: \{length_mm}mm x \{width_mm}mm x \{height_mm}mm (emboss \{emboss_depth_mm}mm)",
    )
    println("Found \{all_paths.length()} graphics for text: '\{name}'")
    println("Curve segments per cubic: \{curve_segments}")
    match out_path {
      Some(path) => println("Writing output to: \{path}")
      None => println("Writing output to stdout")
    }
    match text_raw.bounding_box() {
      Some(b) => println("Raw text bbox: \{b.canonicalize()}")
      None => println("Raw text bbox: None")
    }
    println("Target bbox: \{bbox.canonicalize()}")
    match text.bounding_box() {
      Some(b) => println("Fitted text bbox: \{b.canonicalize()}")
      None => println("Fitted text bbox: None")
    }
  }

  // Base tag.
  let base = @cad.Solid::calibration_chamfer_block(
    length_mm,
    width_mm,
    height_mm,
    chamfer_size_mm=1.0,
    fillet_radius_mm=0.0,
    fillet_segments=10,
    name="tag-base",
  ).translate(x=tx, y=ty, z=tz)
  let mut design = @cad.Design::new(name="keychain-tag").add(base)

  // Text solids (raised on top).
  let mut profile_count = 0
  for g in all_paths {
    let profiles = graphic_to_profiles(g, curve_segments)
    for pi = 0; pi < profiles.length(); pi = pi + 1 {
      let (outer, holes) = profiles[pi]
      profile_count = profile_count + 1
      let solid = @cad.Solid::extruded_profile(
        outer,
        emboss_depth_mm,
        holes~,
        name="text",
      ).translate(x=tx, y=ty, z=tz + height_mm)
      design = design.add(solid)
    }
  }
  if debug {
    println("Generated \{profile_count} extruded text profiles")
  }
  design.write_step(out_path)
}
