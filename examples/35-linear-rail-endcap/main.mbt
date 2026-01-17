///|
/// 35-linear-rail-endcap
///
/// Endcaps that fit common rail profiles, with optional wipers and covers.
/// Demonstrates precision pockets and multi-profile extrusions.
///
/// Usage (stdout):
///   moon run --target native examples/35-linear-rail-endcap -- > endcap.step
///
async fn main {
  let base_args_spec = {
    "railWidth": @cli.opt_double(12.0, help="Linear rail width (mm)"),
    "railHeight": @cli.opt_double(8.0, help="Linear rail height (mm)"),
    "thickness": @cli.opt_double(10.0, help="Endcap thickness (mm)"),
    "clearance": @cli.opt_double(0.2, help="Clearance for the rail pocket (mm)"),
    "seatDiameter": @cli.opt_double(3.5, help="Fastener seat diameter (mm)"),
    "seatDepth": @cli.opt_double(5.0, help="Fastener seat depth (mm)"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    "out": @cli.opt_string(short='o', help="Write output to a file"),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(args_spec, prog="35-linear-rail-endcap") is Some(args) else {
    return
  }
  let rw = args.double("railWidth")
  let rh = args.double("railHeight")
  let thick = args.double("thickness")
  let clr = args.double("clearance")
  let sd = args.double("seatDiameter")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = args.translate_xyz().unwrap_or((0.0, 0.0, 0.0))

  // 1. Endcap Outer Profile (including the rail cutout)
  let body_w = rw + 10.0
  let body_h = rh + 10.0
  let r = 4.0
  let n = 8
  let pw = rw + 2.0 * clr
  let ph = rh + clr
  let outer = []

  // Rail cutout (bottom-center)
  // We'll build CCW.
  // Start bottom-right of cutout
  outer.push((pw / 2.0, -body_h / 2.0))
  // Bottom-right of body (sharp)
  outer.push((body_w / 2.0, -body_h / 2.0))

  // Top-right fillet
  outer.push_iter(
    @cad.Profile2D::arc(2.0 * r, 0.0, 0.5 * @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + body_w / 2.0 - r, p.1 + body_h / 2.0 - r) }),
  )

  // Top-left fillet
  outer.push_iter(
    @cad.Profile2D::arc(2.0 * r, 0.5 * @math.PI, @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 - body_w / 2.0 + r, p.1 + body_h / 2.0 - r) }),
  )

  // Bottom-left of body (sharp)
  outer.push((-body_w / 2.0, -body_h / 2.0))

  // Bottom-left of cutout
  outer.push((-pw / 2.0, -body_h / 2.0))

  // Inside the cutout
  outer.push((-pw / 2.0, -body_h / 2.0 + ph))
  outer.push((pw / 2.0, -body_h / 2.0 + ph))

  // Back to start (pw/2, -body_h/2) - implied

  // 2. Fastener Seat Hole
  let seat_y = ph - body_h / 2.0 + (body_h - ph) / 2.0
  let seat_hole = @cad.Profile2D::circle(sd).rev()
  let seat_hole_translated = @cad.translate_pts(seat_hole, 0.0, seat_y)

  // 3. Create the main solid
  let endcap = @cad.ExtrudedProfile::new(outer, thick, holes=[
      seat_hole_translated,
    ])
    .with_name("rail-endcap")
    .with_color(@cad.Rgb::new(0.1, 0.7, 0.4)) // Beautiful Emerald Green
    .translate(x=tx, y=ty, z=tz)

  // 4. Labels

  let font = @cad.load_font("baloo")
  let hole_top = seat_y + sd / 2.0
  let edge_top = body_h / 2.0
  let label_y = (hole_top + edge_top) / 2.0
  let design = @cad.Design::new(name="linear-rail-endcap")
    .add(endcap)
    .add_text_on_face(
      endcap,
      "MGN" + rw.to_int().to_string(),
      Top,
      font,
      font_size=2.2,
      offset_y=label_y,
    )
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
