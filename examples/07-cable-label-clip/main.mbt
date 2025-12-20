///|
// 07-cable-label-clip
//
// A snap-on cable label clip with programmable text.
//
// Usage (stdout):
//   moon run --target native examples/07-cable-label-clip -- --diameter 5 --text USB > clip.step
//

///|
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(6.0, help="Cable diameter (mm)", min=1.0),
    "text": @cli.opt_string(short='t', help="Label text"),
    "length": @cli.opt_double(20.0, help="Clip length (mm)", min=5.0),
    "thickness": @cli.opt_double(1.5, help="Clip wall thickness (mm)", min=0.5),
    "opening": @cli.opt_double(
      60.0,
      help="Opening angle (degrees)",
      min=10.0,
      max=120.0,
    ),
    "fontSize": @cli.opt_double(8.0, help="Font size", min=1.0),
    "embossDepth": @cli.opt_double(0.5, help="Engraving depth (mm)", min=0.0),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="07-cable-label-clip",
      description="Generate a snap-on cable label clip.",
    )
    is Some(args) else {
    return
  }
  let diameter = args.double("diameter")
  let label_text = args.string_opt("text").unwrap_or("LABEL")
  let clip_length = args.double("length")
  let wall = args.double("thickness")
  let opening_deg = args.double("opening")
  let emboss_depth = args.double("embossDepth")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let mut design = @cad.Design::new(name="cable-label")

  // 1. C-Clip Profile
  // We want a "C" shape. 
  // start_angle = opening / 2, end_angle = 360 - opening / 2
  let open_rad = opening_deg * @math.PI / 180.0
  let start_angle = open_rad / 2.0
  let end_angle = 2.0 * @math.PI - start_angle
  let outer_arc = @cad.Profile2D::arc(
    diameter + 2.0 * wall,
    start_angle,
    end_angle,
    segments=32,
  )
  let inner_arc = @cad.Profile2D::arc(
    diameter,
    start_angle,
    end_angle,
    segments=32,
  )

  // Create closed C-shape by reversing the inner arc and joining
  let c_profile : Array[(Double, Double)] = []
  for pt in outer_arc {
    c_profile.push(pt)
  }
  // Reverse inner arc
  for i in 0..<inner_arc.length() {
    c_profile.push(inner_arc[inner_arc.length() - 1 - i])
  }
  let clip_body = @cad.ExtrudedProfile::new(c_profile, clip_length)
    .with_name("clip-body")
    .with_color(@cad.Rgb::grey())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(clip_body)

  // 2. Label Plaque
  // A flat surface on top of the clip.
  let plaque_width = diameter + wall
  let plaque_thickness = wall
  let plaque = @cad.Cuboid::new(plaque_width, clip_length, plaque_thickness)
    .with_name("label-plaque")
    .with_color(@cad.Rgb::grey())
    .translate(
      x=tx - plaque_width / 2.0,
      y=ty - clip_length / 2.0,
      z=tz + diameter / 2.0 + wall,
    )
  design = design.add(plaque)

  // 3. Text
  let font = @baloo.font
  let margin = 2.0
  let text_bbox = @draw.bbox(
    margin,
    margin,
    plaque_width - margin,
    clip_length - margin,
  )
  let text_raw = @draw.text(text=label_text, font~, align=Center).transform(
    scale=@draw.vec2(1, -1),
  ) catch {
    e => {
      @cli.eprintln("Error creating text: \{e}")
      abort("")
    }
  }
  let text_fitted = text_raw.fit_to(text_bbox)
  let all_paths = text_fitted.all_paths_and_compound_paths()
  for g in all_paths {
    let profiles = @draw.Graphic::to_profiles_tuples(g, 8)
    for profile in profiles {
      let (outer, holes) = profile
      if outer.length() < 3 {
        continue
      }

      // The drawing coordinates are relative to the text_bbox (margin, margin).
      // We need to translate them to sit on top of the plaque.
      let text_solid = @cad.ExtrudedProfile::new(outer, emboss_depth, holes~)
        .with_name("label-text")
        .with_color(@cad.Rgb::orange())
        .translate(
          x=tx - plaque_width / 2.0,
          y=ty - clip_length / 2.0,
          z=tz + diameter / 2.0 + wall + plaque_thickness,
        )
      design = design.add(text_solid)
    }
  }
  design.write_step(out_path)
}
