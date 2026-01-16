///|
/// 24-angled-drill-guide-block
///
/// A drill guide with configurable angles and bushing seat geometry.
///
/// Usage (stdout):
///   moon run --target native examples/24-angled-drill-guide-block -- --angle 15 --holeDiameter 9.5 > guide.step
async fn main {
  let base_args_spec = {
    "angle": @cli.opt_double(
      0.0,
      help="Angle from vertical (degrees)",
      min=-45.0,
      max=45.0,
    ),
    "holeDiameter": @cli.opt_double(
      9.5,
      help="Inner hole diameter for the drill bit (mm). 9.5mm is standard for pocket holes.",
      min=1.0,
    ),
    "outerDiameter": @cli.opt_double(
      20.0,
      help="Outer diameter of the guide body (mm)",
      min=5.0,
    ),
    "height": @cli.opt_double(
      40.0,
      help="Total height of the guide tube (mm)",
      min=10.0,
    ),
    "seatDiameter": @cli.opt_double(
      12.0,
      help="Diameter of the bushing seat (mm)",
      min=0.0,
    ),
    "seatDepth": @cli.opt_double(
      5.0,
      help="Depth of the bushing seat (mm)",
      min=0.0,
    ),
    "baseWidth": @cli.opt_double(
      60.0,
      help="Width of the mounting base (mm)",
      min=20.0,
    ),
    "baseLength": @cli.opt_double(
      40.0,
      help="Length of the mounting base (mm)",
      min=20.0,
    ),
    "baseThickness": @cli.opt_double(
      5.0,
      help="Thickness of the mounting base (mm)",
      min=2.0,
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
      prog="24-angled-drill-guide-block",
      description="Generate a parametric angled drill guide block.",
    )
    is Some(args) else {
    return
  }
  let angle = args.double("angle")
  let hole_dia = args.double("holeDiameter")
  let outer_dia = args.double("outerDiameter")
  let height = args.double("height")
  let seat_dia = args.double("seatDiameter")
  let seat_depth = args.double("seatDepth")
  let base_w = args.double("baseWidth")
  let base_l = args.double("baseLength")
  let base_t = args.double("baseThickness")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = drill_guide(
    angle, hole_dia, outer_dia, height, seat_dia, seat_depth, base_w, base_l, base_t,
  )
  let mut design = @cad.Design::new(name="angled-drill-guide")
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
fn drill_guide(
  angle : Double,
  id : Double,
  od : Double,
  h : Double,
  sd : Double,
  s_depth : Double,
  bw : Double,
  bl : Double,
  bt : Double,
) -> Array[@cad.SceneNode] {
  // 1. The Mounting Base
  // Create a rounded base with four mounting holes and one central angled hole.
  let base_outer = @cad.Profile2D::rounded_rect(bw, bl, 5.0)
  let mounting_hole_dia = 5.0
  let mounting_hole_profile = @cad.Profile2D::circle(mounting_hole_dia)
  let mounting_hole_locs = [
    (10.0, 10.0),
    (bw - 10.0, 10.0),
    (bw - 10.0, bl - 10.0),
    (10.0, bl - 10.0),
  ]

  // Angle hole in base (projection of the guide hole)
  // Width remains 'id', length becomes 'id / cos(angle)'
  let angle_rad = angle * @math.PI / 180.0
  let hole_l = id / @math.cos(angle_rad)
  let guide_hole = @cad.Profile2D::ellipse(id, hole_l)
    .map(fn(p) { (p.0 + bw / 2.0, p.1 + bl / 2.0) })
    .rev()
  let base_profile = @cad.Profile2D::new(base_outer)
    .add_holes_at(mounting_hole_locs, mounting_hole_profile)
    .add_hole(guide_hole)
  let base = @cad.ExtrudedProfile::new(
      base_profile.outer,
      bt,
      holes=base_profile.holes,
    )
    .with_name("base")
    .with_color(@cad.Rgb::blue())
    .translate(x=-bw / 2.0, y=-bl / 2.0)

  // 2. The Guide Tube
  // Extend the tube slightly so it penetrates the base correctly.
  let extra = od / 2.0 * @math.sin(angle_rad.abs())
  let main_guide_h = h - s_depth + extra
  let guide_body = @cad.tube(od, id, main_guide_h)
    .with_name("guide-body")
    .with_color(@cad.Rgb::cyan())
    .translate(z=-extra) // Move start point down
  let seat_body = if s_depth > 0.0 && sd > id {
    @cad.tube(od, sd, s_depth)
    .with_name("bushing-seat")
    .with_color(@cad.Rgb::cyan())
    .translate(z=h - s_depth)
  } else {
    @cad.tube(od, id, s_depth)
    .with_name("guide-top")
    .with_color(@cad.Rgb::cyan())
    .translate(z=h - s_depth)
  }

  // Group guide parts and rotate
  let guide_parts = [guide_body, seat_body]
  let rotated_guide = guide_parts.map(fn(node) {
    let (tx, ty, tz) = @cad.rotate_point(
      (node.tx, node.ty, node.tz),
      angle,
      0.0,
      0.0,
    )
    let new_node = node
      .translate(x=tx - node.tx, y=ty - node.ty, z=tz - node.tz)
      .rotate_x(angle)
    // Place so the rotation point (0,0,0 local) is at top of base
    new_node.translate(z=bt)
  })
  let nodes = [base]
  nodes.push_iter(rotated_guide.iter())
  nodes
}
