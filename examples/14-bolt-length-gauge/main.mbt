///|
/// 14-bolt-length-gauge
///
/// A physical "ruler" for bolts that includes embossed size markings.
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
  let font = @baloo.font

  // 1. Build the profile with holes (2D CSG)
  let holes = []

  // Ruler slot (as a through-hole)
  let slot_poly = [
    (-slot_width / 2.0, 5.0),
    (slot_width / 2.0, 5.0),
    (slot_width / 2.0, length - 5.0),
    (-slot_width / 2.0, length - 5.0),
  ].rev() // must be CW
  holes.push(slot_poly)

  // Bolt holes
  let hole_spacing = length / Double::from_int(bolt_sizes.length() + 1)
  for i in 0..<bolt_sizes.length() {
    let (_, dia) = bolt_sizes[i]
    let hole_y = hole_spacing * Double::from_int(i + 1)
    let hole_x = -width * 0.38
    let h = @cad.Profile2D::circle(dia)
      .map(fn(p) { (p.0 + hole_x, p.1 + hole_y) })
      .rev()
    holes.push(h)
  }

  // 2. Create the main base block
  let outer = @cad.Profile2D::rect(width, length).map(fn(p) {
    (p.0 - width / 2.0, p.1)
  })
  let base = @cad.ExtrudedProfile::new(outer, height, holes~)
    .with_name("gauge-base")
    .with_color(@cad.Rgb::purple())
  let mut design = @cad.Design::new(name="bolt-length-gauge").add(base)

  // 3. Add labels
  for i in 0..<bolt_sizes.length() {
    let (name, _) = bolt_sizes[i]
    let hole_y = hole_spacing * Double::from_int(i + 1)
    let hole_x = -width * 0.38

    // Place labels between the hole and the center slot
    // mid_y is length/2. We want it at hole_y.
    design = design.add_text_on_face(
      base,
      name,
      Top,
      font,
      font_size=3.5,
      offset_x=hole_x + 8.2,
      offset_y=hole_y - length / 2.0,
    )
  }

  // 4. Add ruler markings
  for i in 1..=(length.to_int() / 10 - 1) {
    let pos_y = Double::from_int(i * 10)
    design = design.add_text_on_face(
      base,
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
  design.write_step(out_path)
}
