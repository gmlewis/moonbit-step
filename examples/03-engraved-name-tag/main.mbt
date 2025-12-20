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
  // let fillet_radius_mm = args.double("filletRadius")
  guard args.string_opt("name") is Some(name) else {
    @cli.eprintln("--name is required")
    abort("")
  }
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
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
      @cli.eprintln("Error creating text: \{e}")
      abort("")
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

    let base = @cad.CalibrationChamferBlock::new(

      length_mm,

      width_mm,

      height_mm,

      chamfer_size_mm=1.0,

      fillet_radius_mm=0.0,

      fillet_segments=10,

    ).with_name("tag-base").with_color(@cad.Rgb::grey()).translate(x=tx, y=ty, z=tz)

    let mut design = @cad.Design::new(name="keychain-tag").add(base)

  

  // Text solids (raised on top).
  let mut profile_count = 0
  for g in all_paths {
    // Use the upstream helper that returns polygons as tuples directly.
    let profiles = @draw.Graphic::to_profiles_tuples(g, curve_segments)
    for pi = 0; pi < profiles.length(); pi = pi + 1 {
      let (outer, holes) = profiles[pi]
      if outer.length() < 3 {
        continue
      }
      profile_count = profile_count + 1
      let solid = @cad.ExtrudedProfile::new(outer, emboss_depth_mm, holes~)
        .with_name("text")
        .translate(x=tx, y=ty, z=tz + height_mm)

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
