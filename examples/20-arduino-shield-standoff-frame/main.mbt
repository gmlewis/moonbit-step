///|
/// 20-arduino-shield-standoff-frame
///
/// A working example that generates a STEP model for: A standoff frame that
/// supports stacked boards with computed clearances.
///
/// Usage (stdout):
///   moon run --target native examples/20-arduino-shield-standoff-frame -- --standoffHeight 10 > arduino-frame.step
async fn main {
  let base_args_spec = {
    "frameThickness": @cli.opt_double(
      3.0,
      help="Thickness of the base frame (mm)",
      min=1.0,
    ),
    "standoffHeight": @cli.opt_double(
      10.0,
      help="Height of the standoffs (mm)",
      min=1.0,
    ),
    "standoffOD": @cli.opt_double(
      6.0,
      help="Outer diameter of standoffs (mm)",
      min=1.0,
    ),
    "standoffID": @cli.opt_double(
      3.2,
      help="Inner hole diameter of standoffs (mm)",
      min=0.5,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="20-arduino-shield-standoff-frame",
      description="Generate an Arduino Uno standoff frame STEP model.",
    )
    is Some(args) else {
    return
  }
  let frame_thickness = args.double("frameThickness")
  let standoff_height = args.double("standoffHeight")
  let standoff_od = args.double("standoffOD")
  let standoff_id = args.double("standoffID")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = arduino_uno_standoff_frame(
    frame_thickness, standoff_height, standoff_od, standoff_id,
  )
  let mut design = @cad.Design::new(name="arduino-standoff-frame")
  for node in nodes {
    // Center the board area approximately
    design = design.add(
      node.translate(x=tx - 68.6 / 2.0, y=ty - 53.3 / 2.0, z=tz),
    )
  }
  design.write_step(out_path)
}

///|
fn arduino_uno_standoff_frame(
  frame_thickness : Double,
  standoff_height : Double,
  standoff_diameter : Double,
  standoff_hole_diameter : Double,
) -> Array[@cad.SceneNode] {
  let uno_w = 68.6
  let uno_l = 53.3

  // Increase frame size slightly to support standoffs centered 2.5mm from edge
  let margin = standoff_diameter / 2.0 - 1.5 // Ensure at least 1mm outer support
  let m = if margin < 2.0 { 2.0 } else { margin }
  let width = uno_w + 2.0 * m
  let length = uno_l + 2.0 * m

  // Rail width should be enough to cover the standoff
  let rail_w = standoff_diameter + 2.0
  let outer = @cad.Profile2D::rounded_rect(width, length, 3.0)
  let inner = @cad.Profile2D::rounded_rect(
      width - 2.0 * rail_w,
      length - 2.0 * rail_w,
      2.0,
    )
    .map(fn(p) { (p.0 + rail_w, p.1 + rail_w) })
    .rev()
  let base_frame = @cad.ExtrudedProfile::new(outer, frame_thickness, holes=[
      inner,
    ])
    .with_name("frame")
    .with_color(@cad.Rgb::blue())
    .translate(x=-m, y=-m, z=0.0)
  let nodes = [base_frame]

  // Arduino Uno standard hole pattern (approximate mm from bottom-left corner of board)
  let hole_locs = [(14.0, 2.5), (15.3, 50.8), (66.1, 7.6), (66.1, 35.6)]
  for _, loc in hole_locs {
    let (hx, hy) = loc
    let standoff = @cad.tube(
        standoff_diameter, standoff_hole_diameter, standoff_height,
      )
      .with_name("standoff-{i}")
      .with_color(@cad.Rgb::cyan())
      .translate(x=hx, y=hy, z=frame_thickness)
    nodes.push(standoff)
  }
  nodes
}
