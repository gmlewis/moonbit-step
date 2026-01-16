///|
/// 25-miter-saw-angle-template
///
/// A set of printable angle templates for calibrating miter saw joints.
/// Each wedge represents a standard joint angle.
///
/// Usage (stdout):
///   moon run --target native examples/25-miter-saw-angle-template -- --thickness 5 > templates.step
async fn main {
  let base_args_spec = {
    "angles": @cli.opt_string(
      short='a',
      help="Comma-separated list of angles (degrees). Default: 15,22.5,30,45",
    ),
    "size": @cli.opt_double(
      50.0,
      help="Length of the wedge edges (mm)",
      min=10.0,
    ),
    "thickness": @cli.opt_double(
      5.0,
      help="Thickness of the templates (mm)",
      min=1.0,
    ),
    "holeDiameter": @cli.opt_double(
      5.0,
      help="Diameter of the optional hanging hole (mm)",
      min=0.0,
    ),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="25-miter-saw-angle-template",
      description="Generate miter saw angle templates.",
    )
    is Some(args) else {
    return
  }
  let angles_str = args.string_opt("angles").unwrap_or("15,22.5,30,45")
  let size = args.double("size")
  let thickness = args.double("thickness")
  let hole_dia = args.double("holeDiameter")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let angles = parse_angles(angles_str)
  let design = miter_templates(angles, size, thickness, hole_dia).translate(
    x=tx,
    y=ty,
    z=tz,
  )
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn parse_angles(s : String) -> Array[Double] {
  let parts = s.split(",")
  let out = []
  for p in parts {
    let val = @strconv.parse_double(p.trim().to_string()) catch { _ => 0.0 }
    if val > 0.0 && val < 90.0 {
      out.push(val)
    }
  }
  if out.length() == 0 {
    [15.0, 22.5, 30.0, 45.0]
  } else {
    out
  }
}

///|
async fn miter_templates(
  angles : Array[Double],
  size : Double,
  thickness : Double,
  hole_dia : Double,
) -> @cad.Design {
  let mut design = @cad.Design::new(name="miter-templates")
  let spacing = size + 10.0
  let font = @cad.load_font("baloo")
  for i, angle in angles {
    let x_off = Double::from_int(i) * spacing

    // Wedge profile
    let angle_rad = angle * @math.PI / 180.0
    let h_max = size * @math.tan(angle_rad)
    let base_h = 10.0
    let wedge_poly = [
      (0.0, 0.0),
      (size, 0.0),
      (size, base_h + h_max),
      (0.0, base_h),
    ]
    let mut profile = @cad.Profile2D::new(wedge_poly)
    if hole_dia > 0.0 {
      let hx = size * 0.8
      let hy = base_h * 0.5
      let hole = @cad.Profile2D::circle(hole_dia)
        .map(fn(p) { (p.0 + hx, p.1 + hy) })
        .rev()
      profile = profile.add_hole(hole)
    }
    let wedge = @cad.ExtrudedProfile::new(
        profile.outer,
        thickness,
        holes=profile.holes,
      )
      .with_name("wedge-\{angle}")
      .with_color(@cad.Rgb::purple())
      .translate(x=x_off)
    design = design.add(wedge)

    // Label on the large side face
    let label_text = "\{angle}°"
    design = design.add_text_on_face(
      wedge,
      label_text,
      Top,
      font,
      font_size=base_h * 0.6,
      offset_x=size * 0.3,
      offset_y=0.0,
      color=@cad.Rgb::white(),
    )
  }
  design
}
