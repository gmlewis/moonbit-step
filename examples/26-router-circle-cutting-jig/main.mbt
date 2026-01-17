///|
/// 26-router-circle-cutting-jig
///
/// A circle-cutting jig for a router.
/// Demonstrates complex profile construction and coordinate transformations.
///
/// Usage (stdout):
///   moon run --target native examples/26-router-circle-cutting-jig -- --armLength 300 > jig.step
async fn main {
  let base_args_spec = {
    "baseDiameter": @cli.opt_double(
      150.0,
      help="Diameter of the router base (mm)",
      min=50.0,
    ),
    "armLength": @cli.opt_double(
      300.0,
      help="Total length from bit center to arm end (mm)",
      min=100.0,
    ),
    "armWidth": @cli.opt_double(
      40.0,
      help="Width of the extension arm (mm)",
      min=20.0,
    ),
    "bitHoleDiameter": @cli.opt_double(
      30.0,
      help="Diameter of the central bit hole (mm)",
      min=5.0,
    ),
    "mountHoleSpacing": @cli.opt_double(
      80.0,
      help="Center-to-center spacing of router mounting holes (mm)",
      min=20.0,
    ),
    "mountHoleDiameter": @cli.opt_double(
      6.5,
      help="Diameter of the mounting holes (mm)",
      min=1.0,
    ),
    "pivotSlotWidth": @cli.opt_double(
      6.5,
      help="Width of the pivot adjustment slot (mm)",
      min=1.0,
    ),
    "thickness": @cli.opt_double(
      8.0,
      help="Thickness of the jig plate (mm)",
      min=3.0,
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
      prog="26-router-circle-cutting-jig",
      description="Generate a router circle-cutting jig.",
    )
    is Some(args) else {
    return
  }
  let base_dia = args.double("baseDiameter")
  let arm_l = args.double("armLength")
  let arm_w = args.double("armWidth")
  let bit_dia = args.double("bitHoleDiameter")
  let mount_s = args.double("mountHoleSpacing")
  let mount_dia = args.double("mountHoleDiameter")
  let slot_w = args.double("pivotSlotWidth")
  let thick = args.double("thickness")
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

  // 1. Build the main profile
  let base_r = base_dia / 2.0
  let half_arm_w = arm_w / 2.0
  let base_angle = @math.asin(half_arm_w / base_r)
  let outer_arc = @cad.Profile2D::arc(
    base_dia,
    base_angle,
    2.0 * @math.PI - base_angle,
  )
  let arm_end_pts = [(arm_l, -half_arm_w), (arm_l, half_arm_w)]
  let jig_poly = [..outer_arc, ..arm_end_pts]
  let mut jig_profile = @cad.Profile2D::new(jig_poly)

  // 2. Add holes
  let bit_hole = @cad.Profile2D::circle(bit_dia).rev()
  jig_profile = jig_profile.add_hole(bit_hole)
  let mount_locs = [(0.0, mount_s / 2.0), (0.0, -mount_s / 2.0)]
  let mount_hole_poly = @cad.Profile2D::circle(mount_dia)
  jig_profile = jig_profile.add_holes_at(mount_locs, mount_hole_poly)
  let slot_start = base_r + 10.0
  let slot_end = arm_l - 10.0
  if slot_end > slot_start {
    let slot_poly = [
      (slot_start, -slot_w / 2.0),
      (slot_end, -slot_w / 2.0),
      (slot_end, slot_w / 2.0),
      (slot_start, slot_w / 2.0),
    ].rev()
    jig_profile = jig_profile.add_hole(slot_poly)
  }

  // 3. Create the solid
  let jig = @cad.ExtrudedProfile::new(
      jig_profile.outer,
      thick,
      holes=jig_profile.holes,
    )
    .with_name("router-jig")
    .with_color(@cad.Rgb::orange())

  // 4. Add some labels
  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="router-circle-jig")
    .add(jig)
    .add_text_on_face(
      jig,
      "ROUTER JIG",
      Top,
      font,
      font_size=arm_w * 0.3,
      offset_x=base_r,
      offset_y=arm_w * 0.3,
      color=@cad.Rgb::white(),
    )
    .translate(x=tx, y=ty, z=tz)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
