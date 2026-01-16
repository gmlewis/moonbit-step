///|
/// 16-press-fit-pin-gauge
///
/// A working example that generates a STEP model for: Pins and holes that step
/// through interference values to calibrate press fits.
///
/// Usage (stdout):
///   moon run --target native examples/16-press-fit-pin-gauge -- --pinDiameter 5 --clearance 0.1 > pin-gauge.step
async fn main {
  let base_args_spec = {
    "pinDiameter": @cli.opt_double(
      5.0,
      help="Nominal pin diameter (mm)",
      min=1.0,
    ),
    "clearance": @cli.opt_double(0.0, help="Base clearance (mm)"),
    "interference": @cli.opt_double(0.1, help="Base interference (mm)", min=0.0),
    "stepCount": @cli.opt_double(5.0, help="Number of test steps", min=1.0),
    "clearanceStep": @cli.opt_double(
      0.05,
      help="Clearance increment per step (mm)",
    ),
    "spacing": @cli.opt_double(
      15.0,
      help="Spacing between pins/holes (mm)",
      min=5.0,
    ),
    "baseHeight": @cli.opt_double(
      10.0,
      help="Thickness of the base plate (mm)",
      min=1.0,
    ),
    "pinHeight": @cli.opt_double(15.0, help="Height of the pins (mm)", min=1.0),
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
      prog="16-press-fit-pin-gauge",
      description="Generate a press-fit pin gauge test set.",
    )
    is Some(args) else {
    return
  }
  let pin_diameter = args.double("pinDiameter")
  let clearance = args.double("clearance")
  let interference = args.double("interference")
  let step_count = args.double("stepCount").to_int()
  let clearance_step = args.double("clearanceStep")
  let spacing = args.double("spacing")
  let base_height = args.double("baseHeight")
  let pin_height = args.double("pinHeight")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = pin_gauge(
    pin_diameter, clearance, interference, step_count, clearance_step, spacing, base_height,
    pin_height,
  )
  let mut design = @cad.Design::new(name="press-fit-pin-gauge")
  for node in nodes {
    design = design.add(node.translate(x=tx, y=ty, z=tz))
  }
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn pin_gauge(
  pin_diameter : Double,
  base_clearance : Double,
  base_interference : Double,
  step_count : Int,
  clearance_step : Double,
  spacing : Double,
  base_height : Double,
  pin_height : Double,
) -> Array[@cad.SceneNode] {
  let total_length = Double::from_int(step_count) * spacing
  let base_width = pin_diameter * 3.0

  // Base with holes
  let outer = @cad.Profile2D::rect(total_length, base_width)
  let holes = []
  for i in 0..<step_count {
    let current_clearance = -base_interference +
      Double::from_int(i) * clearance_step +
      base_clearance
    let x = Double::from_int(i) * spacing + spacing / 2.0
    let y = base_width / 2.0
    let hole = @cad.Profile2D::circle(pin_diameter + current_clearance).rev()
    holes.push(hole.map(fn(p) { (p.0 + x, p.1 + y) }))
  }
  let base = @cad.ExtrudedProfile::new(outer, base_height, holes~)
    .with_name("base")
    .with_color(@cad.Rgb::blue())
    .translate(x=0.0, y=-base_width / 2.0, z=0.0)
  let nodes = [base]

  // Pins
  for i in 0..<step_count {
    let x = Double::from_int(i) * spacing + spacing / 2.0
    let y = -base_width
    let pin = @cad.tube(pin_diameter, 0.0, pin_height)
      .with_name("pin-\{i}")
      .with_color(@cad.Rgb::magenta())
      .translate(x~, y~, z=0.0)
    nodes.push(pin)
  }
  nodes
}
