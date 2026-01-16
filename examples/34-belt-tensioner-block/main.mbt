///|
/// 34-belt-tensioner-block
///
/// A tensioner block with computed belt path and teeth geometry.
/// Demonstrates complex profile generation with integrated cutouts and teeth.
///
/// Usage (stdout):
///   moon run --target native examples/34-belt-tensioner-block -- > tensioner.step
///
/// Usage (write file):
///   moon run --target native examples/34-belt-tensioner-block -- -o tensioner.step
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(50.0, help="Block length (mm)"),
    "width": @cli.opt_double(20.0, help="Block width (mm)"),
    "height": @cli.opt_double(15.0, help="Block height (mm)"),
    "beltThickness": @cli.opt_double(1.5, help="Belt thickness (mm)"),
    "toothPitch": @cli.opt_double(2.0, help="Belt tooth pitch (GT2 = 2mm)"),
    "boltDia": @cli.opt_double(4.2, help="Tensioning bolt diameter (mm)"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "out": @cli.opt_string(short='o', help="Write output to a file"),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(args_spec, prog="34-belt-tensioner-block") is Some(args) else {
    return
  }
  let l = args.double("length")
  let w = args.double("width")
  let h = args.double("height")
  let belt_t = args.double("beltThickness")
  let pitch = args.double("toothPitch")
  let bolt_d = args.double("boltDia")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = args.translate_xyz().unwrap_or((0.0, 0.0, 0.0))

  // 1. Side Profile (XZ Plane)
  // We'll extrude this along the Y axis (width)
  let r = 3.0 // corner radius
  let n = 8
  let slot_h = belt_t + 1.0
  let slot_y = h / 2.0 - slot_h / 2.0
  let slot_l = l * 0.7

  // Construct a single CCW loop
  let outer = []

  // Start from the top-right corner of the belt entry
  outer.push((l, slot_y + slot_h))

  // Top-right fillet
  outer.push_iter(
    @cad.Profile2D::arc(2.0 * r, 0.0, 0.5 * @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + l - r, p.1 + h - r) }),
  )

  // Top-left fillet
  outer.push_iter(
    @cad.Profile2D::arc(2.0 * r, 0.5 * @math.PI, @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + r, p.1 + h - r) }),
  )

  // Bottom-left fillet
  outer.push_iter(
    @cad.Profile2D::arc(2.0 * r, @math.PI, 1.5 * @math.PI, segments=n)
    .iter()
    .map(fn(p) { (p.0 + r, p.1 + r) }),
  )

  // Bottom-right corner (SHARP)
  outer.push((l, 0.0))

  // Lower part of the belt entry
  outer.push((l, slot_y))

  // Teeth along the bottom of the slot
  let tooth_h = 0.7
  let tooth_w = pitch / 2.0
  let num_teeth = (slot_l / pitch).to_int()
  for i in 0..<num_teeth {
    let tx = l - Double::from_int(i) * pitch
    // skip first point as it's already pushed as (l, slot_y)
    if i > 0 {
      outer.push((tx, slot_y))
    }
    outer.push((tx - tooth_w / 2.0, slot_y + tooth_h))
    outer.push((tx - tooth_w, slot_y))
  }

  // End of slot - only push if it's not identical to the last tooth point
  let last_tx = l - Double::from_int(num_teeth - 1) * pitch - tooth_w
  if Double::abs(last_tx - (l - slot_l)) > 0.001 {
    outer.push((l - slot_l, slot_y))
  }
  outer.push((l - slot_l, slot_y + slot_h))
  // Back to start (implied by loop)

  // 2. Bolt Hole (must be fully inside and not intersect the slot)
  let bolt_x = (l - slot_l) / 2.0
  let bolt_hole = @cad.Profile2D::circle(bolt_d).rev()
  let bolt_hole_translated = @cad.translate_pts(bolt_hole, bolt_x, h / 2.0)

  // 3. Create the main solid
  let tensioner = @cad.ExtrudedProfile::new(outer, w, holes=[
      bolt_hole_translated,
    ])
    .with_name("tensioner-block")
    .with_color(@cad.Rgb::new(0.2, 0.6, 0.9)) // Beautiful Sky Blue
    .rotate_x(90.0)
    .translate(x=tx - l / 2.0, y=ty + w / 2.0, z=tz)

  // 4. Design and Labels

  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="belt-tensioner")
    .add(tensioner)
    .add_text_on_face(
      tensioner,
      "BELT",
      Top,
      font,
      font_size=4.0,
      offset_y=h / 3.0,
    )
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
