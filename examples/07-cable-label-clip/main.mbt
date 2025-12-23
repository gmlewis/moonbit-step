///|
/// 07-cable-label-clip
///
/// A snap-on cable label clip with programmable text.
///
/// Usage (stdout):
///   moon run --target native examples/07-cable-label-clip -- --diameter 5 --text USB > clip.step
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(6.0, help="Cable diameter (mm)", min=1.0),
    "text": @cli.opt_string(short='t', help="Label text"),
    "length": @cli.opt_double(20.0, help="Clip length (mm)", min=5.0),
    "thickness": @cli.opt_double(1.5, help="Clip wall thickness (mm)", min=0.5),
    "opening": @cli.opt_double(
      100.0,
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

  //
  let open_rad = opening_deg * @math.PI / 180.0
  // Opening faces -Y (front)
  let start_angle = -(@math.PI / 2.0) + open_rad / 2.0
  let end_angle = 3.0 * @math.PI / 2.0 - open_rad / 2.0
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

  //
  let c_profile : Array[(Double, Double)] = []
  c_profile.push_iter(outer_arc.iter())
  c_profile.push_iter(inner_arc.rev().iter())

  // 1. The C-clip body (extruded along Z)
  let clip_body = @cad.ExtrudedProfile::new(c_profile, clip_length)
    .with_name("clip-body")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty, z=tz)
  design = design.add(clip_body)

  // 2. Label Plaque
  // We place it on the TOP surface (facing +Y)
  let plaque_width = diameter + wall
  let plaque_thickness = wall
  let plaque = @cad.Cuboid::new(plaque_width, plaque_thickness, clip_length)
    .with_name("label-plaque")
    .with_color(@cad.Rgb::green())
    .translate(x=tx - plaque_width / 2.0, y=ty + diameter / 2.0, z=tz)
  design = design.add(plaque)

  // 3. Text
  let text_font = @baloo.font
  let margin = 2.0
  let text_bbox = @draw.bbox(
    margin,
    margin,
    plaque_width - margin,
    clip_length - margin,
  )
  let text_fitted = @draw.to_graphic(
    text_font,
    label_text,
    alignment=Center,
    y_up=true,
  ).scale_to_fit(text_bbox, anchor=Center) catch {
    e => {
      @cli.eprintln("Error creating text: \{e}")
      abort("")
    }
  }
  let all_paths = text_fitted.all_paths_and_compound_paths()

  //
  let text_solids = all_paths
    .iter()
    .flat_map(fn(g) {
      @draw.Graphic::to_profiles_tuples(g, 8)
      .iter()
      .filter_map(fn(profile) {
        let (outer, holes) = profile
        if outer.length() < 3 {
          return None
        }

        // ExtrudedProfile is XY plane, extruding along Z.
        // We rotate it -90 deg around X so its "Z" (height) becomes "Y" (facing out),
        // and its "Y" becomes "Z" (along the clip).
        // We translate by z=tz + clip_length because Local Y maps to Global -Z.
        let solid = @cad.ExtrudedProfile::new(outer, emboss_depth, holes~)
          .with_name("label-text")
          .with_color(@cad.Rgb::orange())
          .rotate_x(-90)
          .rotate_y(180) // make the text upright
          .translate(
            x=tx + plaque_width / 2.0,
            y=ty + diameter / 2.0 + plaque_thickness - 0.01,
            z=tz,
          )
        Some(solid)
      })
    })
  design = design.add_iter(text_solids)

  //
  let design = design.rotate_z(180) // better viewing angle
  design.write_step(out_path)
}
