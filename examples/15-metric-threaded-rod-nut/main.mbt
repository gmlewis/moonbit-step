///|
/// 15-metric-threaded-rod-nut
///
/// A working example that generates a STEP model for a nut-like coupler body
/// with correct clearances.
///
/// Usage (stdout):
///   moon run --target native examples/15-metric-threaded-rod-nut -- --boltDiameter 8 --clearance 0.1 > nut-strip.step
async fn main {
  let base_args_spec = {
    "boltDiameter": @cli.opt_double(
      8.0,
      help="Nominal bolt diameter (mm)",
      min=1.0,
    ),
    "clearance": @cli.opt_double(0.1, help="Base clearance (mm)", min=0.0),
    "interference": @cli.opt_double(0.0, help="Base interference (mm)", min=0.0),
    "stepCount": @cli.opt_double(5.0, help="Number of test steps", min=1.0),
    "clearanceStep": @cli.opt_double(
      0.05,
      help="Clearance increment per step (mm)",
    ),
    "holeSpacing": @cli.opt_double(
      20.0,
      help="Spacing between holes (mm)",
      min=5.0,
    ),
    "mountThickness": @cli.opt_double(
      5.0,
      help="Thickness of the base plate (mm)",
      min=1.0,
    ),
    "nutHeight": @cli.opt_double(
      0.0,
      help="Height of the nut (0 for standard)",
      min=0.0,
    ),
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
      prog="15-metric-threaded-rod-nut",
      description="Generate a metric threaded rod nut test strip.",
    )
    is Some(args) else {
    return
  }
  let bolt_diameter = args.double("boltDiameter")
  let clearance = args.double("clearance")
  let interference = args.double("interference")
  let step_count = args.double("stepCount").to_int()
  let clearance_step = args.double("clearanceStep")
  let hole_spacing = args.double("holeSpacing")
  let mount_thickness = args.double("mountThickness")
  let nut_height_opt = args.double("nutHeight")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nut_height = if nut_height_opt > 0.0 {
    Some(nut_height_opt)
  } else {
    None
  }
  let nodes = metric_nut_test_strip(
    bolt_diameter,
    clearance,
    interference,
    step_count,
    clearance_step,
    hole_spacing,
    mount_thickness,
    nut_height?,
  )
  let mut design = @cad.Design::new(name="metric-threaded-rod-nut")
  for node in nodes {
    design = design.add(node.translate(x=tx, y=ty, z=tz))
  }
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn metric_nut_test_strip(
  bolt_diameter : Double,
  base_clearance : Double,
  base_interference : Double,
  step_count : Int,
  clearance_step : Double,
  hole_spacing : Double,
  mount_thickness : Double,
  nut_height? : Double,
) -> Array[@cad.SceneNode] {
  let (s, h) = metric_nut_dimensions(bolt_diameter)
  let nut_h = nut_height.unwrap_or(h)
  let total_length = Double::from_int(step_count) * hole_spacing
  let base_width = s + 10.0
  let base = @cad.Cuboid::new(total_length, base_width, mount_thickness)
    .with_name("base")
    .with_color(@cad.Rgb::cyan())
    .translate(x=0.0, y=-base_width / 2.0, z=0.0)
  let nodes = [base]
  for i in 0..<step_count {
    let current_clearance = -base_interference +
      Double::from_int(i) * clearance_step +
      base_clearance
    let x = Double::from_int(i) * hole_spacing + hole_spacing / 2.0
    let nut = metric_nut(bolt_diameter, current_clearance, height=nut_h)
      .with_name("nut-\{i}")
      .with_color(@cad.Rgb::orange())
      .translate(x~, y=0.0, z=mount_thickness)
    nodes.push(nut)
  }
  nodes
}

///|
fn metric_nut_dimensions(bolt_diameter : Double) -> (Double, Double) {
  if bolt_diameter <= 3.0 {
    (5.5, 2.4)
  } else if bolt_diameter <= 4.0 {
    (7.0, 3.2)
  } else if bolt_diameter <= 5.0 {
    (8.0, 4.0)
  } else if bolt_diameter <= 6.0 {
    (10.0, 5.0)
  } else if bolt_diameter <= 8.0 {
    (13.0, 6.5)
  } else if bolt_diameter <= 10.0 {
    (17.0, 8.0)
  } else if bolt_diameter <= 12.0 {
    (19.0, 10.0)
  } else {
    // Heuristic for larger bolts: S approx 1.7 * D, H approx 0.8 * D
    (bolt_diameter * 1.7, bolt_diameter * 0.8)
  }
}

///|
fn metric_nut(
  bolt_diameter : Double,
  clearance : Double,
  height? : Double,
) -> @cad.Shape {
  let (s, h) = metric_nut_dimensions(bolt_diameter)
  let height = height.unwrap_or(h)
  let d = s / @math.cos(30.0 * @math.PI / 180.0)
  let outer = @cad.Profile2D::polygon(6, d, rotation=30.0)
  let hole = @cad.Profile2D::circle(bolt_diameter + clearance).rev()
  @cad.ExtrudedProfile::new(outer, height, holes=[hole])
}
