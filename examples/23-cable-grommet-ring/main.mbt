///|
/// 23-cable-grommet-ring
///
/// A parametric grommet for cable pass-throughs with lip and retention features.
///
/// Usage (stdout):
///   moon run --target native examples/23-cable-grommet-ring -- --innerDiameter 10 --panelThickness 3 > grommet.step
async fn main {
  let base_args_spec = {
    "innerDiameter": @cli.opt_double(
      10.0,
      help="Inner hole diameter for the cable (mm)",
      min=1.0,
    ),
    "panelDiameter": @cli.opt_double(
      16.0,
      help="Diameter of the hole in the panel (mm)",
      min=2.0,
    ),
    "lipDiameter": @cli.opt_double(
      22.0,
      help="Outer diameter of the grommet lips (mm)",
      min=3.0,
    ),
    "panelThickness": @cli.opt_double(
      3.0,
      help="Thickness of the panel it fits into (mm)",
      min=0.5,
    ),
    "lipThickness": @cli.opt_double(
      2.0,
      help="Thickness of the retention lips (mm)",
      min=0.5,
    ),
    "split": @cli.flag(help="Split the grommet into two halves"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="23-cable-grommet-ring",
      description="Generate a parametric cable grommet.",
    )
    is Some(args) else {
    return
  }
  let id = args.double("innerDiameter")
  let pd = args.double("panelDiameter")
  let ld = args.double("lipDiameter")
  let pt = args.double("panelThickness")
  let lt = args.double("lipThickness")
  let split = args.flag("split")
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
  if id >= pd {
    @cli.eprintln("error: innerDiameter must be less than panelDiameter")
    return
  }
  if pd >= ld {
    @cli.eprintln("error: panelDiameter must be less than lipDiameter")
    return
  }
  let nodes = cable_grommet(id, pd, ld, pt, lt, split~)
  let mut design = @cad.Design::new(name="cable-grommet")
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
fn cable_grommet(
  id : Double,
  pd : Double,
  ld : Double,
  pt : Double,
  lt : Double,
  split? : Bool = false,
) -> Array[@cad.SceneNode] {
  if !split {
    // Single part
    let bottom_lip = @cad.tube(ld, id, lt)
      .with_name("bottom-lip")
      .with_color(@cad.Rgb::blue())
    let groove = @cad.tube(pd, id, pt)
      .with_name("groove")
      .with_color(@cad.Rgb::cyan())
      .translate(z=lt)
    let top_lip = @cad.tube(ld, id, lt)
      .with_name("top-lip")
      .with_color(@cad.Rgb::blue())
      .translate(z=lt + pt)
    [bottom_lip, groove, top_lip]
  } else {
    // Two halves
    let nodes = []
    let half_spacing = 5.0
    for i in 0..<2 {
      let ty = if i == 0 { half_spacing } else { -half_spacing }
      let name_suffix = if i == 0 { "a" } else { "b" }
      let rotation = if i == 0 { 0.0 } else { 180.0 }

      // We can't easily "cut" a tube in half with current primitives
      // unless we define a semi-circle profile.
      let start_angle = 0.0
      let end_angle = @math.PI
      let outer_arc = @cad.Profile2D::arc(ld, start_angle, end_angle)
      let inner_arc = @cad.Profile2D::arc(id, start_angle, end_angle).rev()
      let half_lip_profile = [..outer_arc, ..inner_arc]
      let outer_groove_arc = @cad.Profile2D::arc(pd, start_angle, end_angle)
      let half_groove_profile = [..outer_groove_arc, ..inner_arc]
      let b_lip = @cad.ExtrudedProfile::new(half_lip_profile, lt)
        .with_name("bottom-lip-\{name_suffix}")
        .with_color(@cad.Rgb::blue())
        .rotate_z(rotation)
        .translate(y=ty)
      let grv = @cad.ExtrudedProfile::new(half_groove_profile, pt)
        .with_name("groove-\{name_suffix}")
        .with_color(@cad.Rgb::cyan())
        .rotate_z(rotation)
        .translate(y=ty, z=lt)
      let t_lip = @cad.ExtrudedProfile::new(half_lip_profile, lt)
        .with_name("top-lip-\{name_suffix}")
        .with_color(@cad.Rgb::blue())
        .rotate_z(rotation)
        .translate(y=ty, z=lt + pt)
      nodes.push(b_lip)
      nodes.push(grv)
      nodes.push(t_lip)
    }
    nodes
  }
}
