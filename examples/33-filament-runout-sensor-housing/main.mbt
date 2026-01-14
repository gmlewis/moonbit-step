///|
/// 33-filament-runout-sensor-housing
///
/// A housing generator with controlled clearances for switches and fasteners.
/// Demonstrates complex assemblies, rounded profiles, and face-based engraving.
///
/// Usage (stdout):
///   moon run --target native examples/33-filament-runout-sensor-housing -- > housing.step
///
/// Usage (write file):
///   moon run --target native examples/33-filament-runout-sensor-housing -- -o housing.step
async fn main {
  let base_args_spec = {
    "bodyLength": @cli.opt_double(
      45.0,
      help="Housing body length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "bodyWidth": @cli.opt_double(
      30.0,
      help="Housing body width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "bodyHeight": @cli.opt_double(
      18.0,
      help="Housing body height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "wallThickness": @cli.opt_double(
      3.0,
      help="Wall thickness (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "filamentDia": @cli.opt_double(
      1.75,
      help="Filament diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "filamentClearance": @cli.opt_double(
      0.6,
      help="Clearance around filament (mm)",
      min=0.0,
    ),
    "switchWidth": @cli.opt_double(
      20.0,
      help="Microswitch width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "switchLength": @cli.opt_double(
      10.0,
      help="Microswitch length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "switchHeight": @cli.opt_double(
      6.0,
      help="Microswitch height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="33-filament-runout-sensor-housing",
      description="Generate a filament runout sensor housing.",
    )
    is Some(args) else {
    return
  }
  let body_l = args.double("bodyLength")
  let body_w = args.double("bodyWidth")
  let body_h = args.double("bodyHeight")
  let wall = args.double("wallThickness")
  let fil_path_dia = args.double("filamentDia") +
    args.double("filamentClearance")
  let sw_w = args.double("switchWidth")
  let sw_l = args.double("switchLength")
  let sw_h = args.double("switchHeight")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // 1. Main Housing Body (Side-view extrusion to include filament bore)
  let body_radius = 4.0
  let n = 8
  let side_pts = []
  // Bottom-right arc
  side_pts.push_iter(
    @cad.Profile2D::arc(
      2.0 * body_radius,
      1.5 * @math.PI,
      2.0 * @math.PI,
      segments=n,
    )
    .iter()
    .map(fn(p) { (p.0 + body_l - body_radius, p.1 + body_radius) }),
  )
  // Top-right arc
  side_pts.push_iter(
    @cad.Profile2D::arc(2.0 * body_radius, 0.0, 0.5 * @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + body_l - body_radius, p.1 + body_h - body_radius) }),
  )
  // Top-left arc
  side_pts.push_iter(
    @cad.Profile2D::arc(2.0 * body_radius, 0.5 * @math.PI, @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + body_radius, p.1 + body_h - body_radius) }),
  )
  // Bottom-left corner (SHARP) - this corner touches the mounting bracket
  side_pts.push((0.0, 0.0))
  let fil_hole = @cad.Profile2D::circle(fil_path_dia).rev()
  let fil_hole_translated = @cad.translate_pts(
    fil_hole,
    body_l / 2.0,
    body_h / 2.0,
  )
  let housing = @cad.ExtrudedProfile::new(side_pts, body_w, holes=[
      fil_hole_translated,
    ])
    .with_name("housing")
    .with_color(@cad.Rgb::new(0.6, 0.2, 0.8)) // Vibrant Purple
    .rotate_x(90.0)
    .translate(x=tx - body_l / 2.0, y=ty + body_w / 2.0, z=tz)

  // 2. Mounting Flange
  let flange_w = body_w + 15.0
  let flange_l = 12.0
  let flange_outer = @cad.Profile2D::rounded_rect(flange_l, flange_w, 3.0)
  let m_hole = @cad.Profile2D::circle(4.0).rev()
  let flange_holes = [
    @cad.translate_pts(m_hole, flange_l / 2.0, 5.0),
    @cad.translate_pts(m_hole, flange_l / 2.0, flange_w - 5.0),
  ]
  let flange = @cad.ExtrudedProfile::new(flange_outer, wall, holes=flange_holes)
    .with_name("flange")
    .with_color(@cad.Rgb::new(0.4, 0.1, 0.6)) // Darker Purple
    .rotate_y(-90.0)
    .translate(x=tx - body_l / 2.0, y=ty - flange_w / 2.0, z=tz)

  // 3. The Microswitch (Placeholder)
  let switch = @cad.Cuboid::new(sw_w, sw_l, sw_h)
    .with_name("microswitch")
    .with_color(@cad.Rgb::magenta())
    .translate(x=tx - sw_w / 2.0, y=ty - sw_l / 2.0, z=tz + body_h / 2.0 + 1.0)

  // 4. Design and Labels
  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="filament-runout-sensor")
    .add(housing)
    .add(flange)
    .add(switch)
    .add_text_on_face(
      housing,
      "FILAMENT",
      Front,
      font,
      font_size=4.0,
      offset_y=4.0,
      rotation=180.0,
    )
    .add_text_on_face(
      housing,
      "SENSOR",
      Front,
      font,
      font_size=4.0,
      offset_y=-4.0,
      rotation=180.0,
    )
  design.write_step(out_path)
}
