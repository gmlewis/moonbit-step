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
// The original example included several local helpers to convert paths and
// graphics to polygon profiles. These helpers are now provided by the
// updated `gmlewis/fonts` package as `Path::to_polygon` and
// `Graphic::to_profiles`. Use those implementations for clarity and
// maintainability.

///|
fn vec2s_to_tuples(vs : Array[@draw.Vec2]) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for v in vs {
    out.push((v.x, v.y))
  }
  out
}

///|
// Lightweight polygon diagnostics for debugging OCCT import failures.
fn signed_area(poly : Array[(Double, Double)]) -> Double {
  let sum : Double = 0.0
  for i = 0; i < poly.length(); i = i + 1 {
    let j = if i + 1 < poly.length() { i + 1 } else { 0 }
    let (x0, y0) = poly[i]
    let (x1, y1) = poly[j]
    sum = sum + (x0 * y1 - x1 * y0)
  }
  0.5 * sum
}

fn nearly_equal(a : Double, b : Double, eps? : Double) -> Bool {
  let e = if eps.is_some() { eps.unwrap() } else { 1e-9 }
  (a - b).abs() <= e
}

fn has_consecutive_duplicates(poly : Array[(Double, Double)]) -> Bool {
  if poly.length() <= 1 { return false }
  for i = 1; i < poly.length(); i = i + 1 {
    if nearly_equal(poly[i].0, poly[i - 1].0) && nearly_equal(poly[i].1, poly[i - 1].1) {
      return true
    }
  }
  false
}

fn orient(ax : Double, ay : Double, bx : Double, by : Double, cx : Double, cy : Double) -> Double {
  (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
}

fn on_segment(ax : Double, ay : Double, bx : Double, by : Double, cx : Double, cy : Double) -> Bool {
  // Check if C lies on segment AB (collinear + within bounds)
  if !nearly_equal(orient(ax, ay, bx, by, cx, cy), 0.0) { return false }
  let minx = if ax < bx { ax } else { bx }
  let maxx = if ax > bx { ax } else { bx }
  let miny = if ay < by { ay } else { by }
  let maxy = if ay > by { ay } else { by }
  cx >= minx && cx <= maxx && cy >= miny && cy <= maxy
}

fn segments_intersect(a1 : (Double, Double), a2 : (Double, Double), b1 : (Double, Double), b2 : (Double, Double)) -> Bool {
  let (a1x, a1y) = a1
  let (a2x, a2y) = a2
  let (b1x, b1y) = b1
  let (b2x, b2y) = b2
  let o1 = orient(a1x, a1y, a2x, a2y, b1x, b1y)
  let o2 = orient(a1x, a1y, a2x, a2y, b2x, b2y)
  let o3 = orient(b1x, b1y, b2x, b2y, a1x, a1y)
  let o4 = orient(b1x, b1y, b2x, b2y, a2x, a2y)

  if o1 * o2 < 0.0 && o3 * o4 < 0.0 {
    return true
  }
  if nearly_equal(o1, 0.0) && on_segment(a1x, a1y, a2x, a2y, b1x, b1y) { return true }
  if nearly_equal(o2, 0.0) && on_segment(a1x, a1y, a2x, a2y, b2x, b2y) { return true }
  if nearly_equal(o3, 0.0) && on_segment(b1x, b1y, b2x, b2y, a1x, a1y) { return true }
  if nearly_equal(o4, 0.0) && on_segment(b1x, b1y, b2x, b2y, a2x, a2y) { return true }
  false
}

fn polygon_has_self_intersections(poly : Array[(Double, Double)]) -> Bool {
  let n = poly.length()
  if n < 4 { return false }
  for i = 0; i < n; i = i + 1 {
    let i2 = (i + 1) % n
    for j = i + 1; j < n; j = j + 1 {
      let j2 = (j + 1) % n
      // Skip adjacent edges (they share a vertex)
      if i == j || i2 == j || j2 == i { continue }
      if segments_intersect(poly[i], poly[i2], poly[j], poly[j2]) {
        return true
      }
    }
  }
  false
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
    "exportProfilesDir": @cli.opt_string(
      help="Write each text profile as a separate STEP file to this directory",
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
  let export_profiles_dir = args.string_opt("exportProfilesDir")
  // If an export dir is provided, we'll attempt to write files there; callers
  // should create the directory if needed. We rely on write_step's error
  // handling below to report any I/O errors.
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
    // Use the new API that returns polygons as arrays of Vec2.
    let profiles_vec = @draw.Graphic::to_profiles(g, curve_segments)
    for pi = 0; pi < profiles_vec.length(); pi = pi + 1 {
      let (outer_vec, holes_vecs) = profiles_vec[pi]
      let outer = vec2s_to_tuples(outer_vec)
      if outer.length() < 3 {
        continue
      }
      let holes : Array[Array[(Double, Double)]] = []
      for h in holes_vecs {
        holes.push(vec2s_to_tuples(h))
      }

      // Diagnostic checks: area (winding), consecutive duplicates, and self-intersections.
      if export_profiles_dir is Some(_) || debug {
        let area = signed_area(outer)
        let winding = if area > 0.0 { "CCW" } else { "CW" }
        let dup = has_consecutive_duplicates(outer)
        let selfint = polygon_has_self_intersections(outer)
        println(
          "Profile diag: pts=\{outer.length()} area=\{area} winding=\{winding} dup=\{dup} selfint=\{selfint}",
        )
        for hi = 0; hi < holes.length(); hi = hi + 1 {
          let hole = holes[hi]
          let harea = signed_area(hole)
          let hself = polygon_has_self_intersections(hole)
          println("  Hole \{hi}: pts=\{hole.length()} area=\{harea} selfint=\{hself}")
        }
      }

      profile_count = profile_count + 1
      let solid = @cad.Solid::extruded_profile(
        outer,
        emboss_depth_mm,
        holes~,
        name="text",
      ).translate(x=tx, y=ty, z=tz + height_mm)

      // If requested, also write this profile to a separate STEP file for isolated validation.
      match export_profiles_dir {
        Some(dir) => {
          let profile_name = "profile-" + profile_count.to_string() + ".step"
          let out_path = dir + "/" + profile_name
          let one = @cad.Design::new(name=profile_name).add(solid)
          one.write_step(Some(out_path)) catch {
            e => println("Failed to write profile \{out_path}: \{e}")
          }
        }
        None => ()
      }
      design = design.add(solid)
    }
  }
  if debug {
    println("Generated \{profile_count} extruded text profiles")
  }
  design.write_step(out_path)
}
