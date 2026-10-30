///|
/// 15-metric-threaded-rod-nut
///
/// A working example that generates a STEP model for a nut-like coupler body
/// with modeled internal threads and correct clearances.
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
  }
  let args_spec = @cli.with_translate(@common.with_output_args(base_args_spec))
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
  let output = @common.output_paths(args)
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
  let mut design = @cad.Design::new(
    name="metric-threaded-rod-nut",
    documentation=args.documentation(),
  )
  for node in nodes {
    design = design.add(node.translate(x=tx, y=ty, z=tz))
  }
  @common.write_output(design, output)
}

///|
fn metric_nut_test_strip(
  bolt_diameter : Double,
  base_clearance : Double,
  base_interference : Double,
  step_count : Int32,
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
    let nut_nodes = metric_nut(
      bolt_diameter,
      current_clearance,
      height=nut_h,
      name_prefix="nut-\{i}",
    )
    for node in nut_nodes {
      nodes.push(node.translate(x~, y=0.0, z=mount_thickness))
    }
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
/// metric_thread_pitch returns the coarse metric pitch for a nominal diameter.
fn metric_thread_pitch(bolt_diameter : Double) -> Double {
  if bolt_diameter <= 3.0 {
    0.5
  } else if bolt_diameter <= 4.0 {
    0.7
  } else if bolt_diameter <= 5.0 {
    0.8
  } else if bolt_diameter <= 6.0 {
    1.0
  } else if bolt_diameter <= 8.0 {
    1.25
  } else if bolt_diameter <= 10.0 {
    1.5
  } else if bolt_diameter <= 12.0 {
    1.75
  } else if bolt_diameter <= 16.0 {
    2.0
  } else {
    bolt_diameter * 0.125
  }
}

///|
/// metric_nut returns the hex body plus a helical internal-thread ridge.
///
/// The bore is at the thread root (major diameter). The ridge is a solid swept
/// along a right-hand helix: its crest sits at the minor diameter and its root
/// is embedded `embed` into the bore wall, so the two bodies fuse when printed.
fn metric_nut(
  bolt_diameter : Double,
  clearance : Double,
  height? : Double,
  name_prefix~ : String = "nut",
) -> Array[@cad.SceneNode] {
  let (s, h) = metric_nut_dimensions(bolt_diameter)
  let height = height.unwrap_or(h)
  let pitch = metric_thread_pitch(bolt_diameter)
  let major_d = bolt_diameter + clearance
  // ISO 68-1 basic profile: 60-degree flanks and an internal radial thread
  // depth of H1 = 0.54125 * pitch. The ridge is a trapezoid whose crest is
  // P/4 wide at the minor diameter and whose root is 7P/8 wide at the major
  // diameter, leaving the standard P/8 groove at the root.
  let depth = 0.54125 * pitch
  let half_depth = depth / 2.0
  let crest_half = 0.125 * pitch
  let root_half = 0.4375 * pitch
  let minor_d = major_d - 2.0 * depth
  let d = s / @math.cos(30.0 * @math.PI / 180.0)
  let outer = @cad.Profile2D::polygon(6, d, rotation=30.0)
  let hole = @cad.Profile2D::circle(major_d).rev()
  let body = @cad.ExtrudedProfile::new(outer, height, holes=[hole])
    .with_name(name_prefix)
    .with_color(@cad.Rgb::orange())
  // Thread ridge cross-section in the radial-axial plane: a trapezoid with the
  // crest (inner radius) on the left and the root (outer radius) on the right.
  let r_major = major_d / 2.0
  let r_minor = minor_d / 2.0
  let r_mid = (r_major + r_minor) / 2.0
  let embed = 0.1
  let profile = @cad.SweepProfile::new([
    (-half_depth, 0.0, -crest_half),
    (half_depth + embed, 0.0, -root_half),
    (half_depth + embed, 0.0, root_half),
    (-half_depth, 0.0, crest_half),
  ])
  // Leave half a pitch at each end so the ridge does not stick out of the nut.
  let thread_turns = (height - pitch) / pitch
  if thread_turns <= 0.0 {
    return [body]
  }
  let path = @cad.helix_path(
    pos=(0.0, 0.0, pitch / 2.0),
    size_per_turn=(r_mid, r_mid, pitch),
    num_turns=thread_turns,
    num_segs_per_turn=32,
    start_angle=0.0,
    clockwise=false,
  )
  // The thread ridge must follow the helical path.
  let thread = @cad.SweptProfile::new(path~, profile~, straight_outline=false)
    .with_name(name_prefix + "-thread")
    .with_color(@cad.Rgb::red())
  [body, thread]
}
