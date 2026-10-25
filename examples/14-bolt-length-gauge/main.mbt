///|
/// 14-bolt-length-gauge
///
/// A physical "ruler" for bolts that includes embossed size markings and
/// 5 mm/10 mm scribed tick marks on the top face.
///
/// Usage (stdout):
///   moon run --target native examples/14-bolt-length-gauge -- > gauge.step
///
/// Usage (write file):
///   moon run --target native examples/14-bolt-length-gauge -- -o gauge.step
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(100.0, help="Length of the gauge (mm)", min=50.0),
    "width": @cli.opt_double(50.0, help="Width of the gauge (mm)", min=20.0),
    "height": @cli.opt_double(10.0, help="Height of the gauge (mm)", min=5.0),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
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
      prog="14-bolt-length-gauge",
      description="Generate a bolt length gauge.",
    )
    is Some(args) else {
    return
  }
  let length = args.double("length")
  let width = args.double("width")
  let height = args.double("height")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  //
  let bolt_sizes = [
    ("M3", 3.4),
    ("M4", 4.4),
    ("M5", 5.4),
    ("M6", 6.4),
    ("M8", 8.4),
  ]
  let slot_width = 10.0
  let font = @cad.load_font("baloo")
  let scribe_depth = 0.5
  let scribe_width = 0.8

  // 1. Through-holes shared by both layers (ruler slot and bolt holes).
  let through_holes = []

  // Ruler slot (as a through-hole)
  let slot_poly = [
    (-slot_width / 2.0, 5.0),
    (slot_width / 2.0, 5.0),
    (slot_width / 2.0, length - 5.0),
    (-slot_width / 2.0, length - 5.0),
  ].rev() // must be CW
  through_holes.push(slot_poly)

  // Bolt holes
  let hole_spacing = length / Double::from_int(bolt_sizes.length() + 1)
  for i in 0..<bolt_sizes.length() {
    let (_, dia) = bolt_sizes[i]
    let hole_y = hole_spacing * Double::from_int(i + 1)
    let hole_x = -width * 0.38
    let h = @cad.Profile2D::circle(dia)
      .map(fn(p) { (p.0 + hole_x, p.1 + hole_y) })
      .rev()
    through_holes.push(h)
  }

  // 2. Scribed tick slots on the top face, to the right of the numbers.
  // Deep notches every 10 mm match the labels; shallow ones every 5 mm sit
  // between them. The slots go through a thin top layer, so they are exactly
  // `scribe_depth` deep and expose the lower slab as their floor.
  let tick_x0 = width / 4.0 + 3.5
  let max_len = width / 2.0 - tick_x0 - 1.0
  let major_len = if max_len < 6.0 { max_len } else { 6.0 }
  let minor_len = major_len * 0.55
  let scribe_holes = []
  let steps = (length / 5.0).to_int()
  for i in 1..<steps {
    let y = Double::from_int(i) * 5.0
    if y > length - 2.0 {
      continue
    }
    let major = i % 2 == 0
    let len = if major { major_len } else { minor_len }
    if len <= 0.5 {
      continue
    }
    let x1 = tick_x0 + len
    scribe_holes.push(
      [
        (tick_x0, y - scribe_width / 2.0),
        (x1, y - scribe_width / 2.0),
        (x1, y + scribe_width / 2.0),
        (tick_x0, y + scribe_width / 2.0),
      ].rev(),
    )
  }

  // 3. Lower slab plus a thin marking layer. The scribe slots are holes in the
  // marking layer only, so the marks are shallow face notches, not cut-outs.
  let outer = @cad.Profile2D::rect(width, length).map(fn(p) {
    (p.0 - width / 2.0, p.1)
  })
  let lower = @cad.ExtrudedProfile::new(
      outer,
      height - scribe_depth,
      holes=through_holes,
    )
    .with_name("gauge-base")
    .with_color(@cad.Rgb::purple())
  let top_holes = through_holes.copy()
  top_holes.push_iter(scribe_holes.iter())
  let top = @cad.ExtrudedProfile::new(outer, scribe_depth, holes=top_holes)
    .with_name("gauge-marking-face")
    .with_color(@cad.Rgb::purple())
    .translate(z=height - scribe_depth)
  let mut design = @cad.Design::new(
      name="bolt-length-gauge",
      documentation=args.documentation(),
    )
    .add(lower)
    .add(top)

  // 4. Add labels
  for i in 0..<bolt_sizes.length() {
    let (name, _) = bolt_sizes[i]
    let hole_y = hole_spacing * Double::from_int(i + 1)
    let hole_x = -width * 0.38

    // Place labels between the hole and the center slot
    // mid_y is length/2. We want it at hole_y.
    design = design.add_text_on_face(
      top,
      name,
      Top,
      font,
      font_size=3.5,
      offset_x=hole_x + 8.2,
      offset_y=hole_y - length / 2.0,
    )
  }

  // 5. Add ruler markings
  for i in 1..<=(length.to_int() / 10 - 1) {
    let pos_y = Double::from_int(i * 10)
    design = design.add_text_on_face(
      top,
      pos_y.to_int().to_string(),
      Top,
      font,
      font_size=3.5,
      offset_x=width / 4.0,
      offset_y=pos_y - length / 2.0,
    )
  }

  //
  design = design.translate(x=tx, y=ty, z=tz)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
