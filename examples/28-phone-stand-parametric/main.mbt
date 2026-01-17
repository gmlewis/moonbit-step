///|
/// 28-phone-stand-parametric
///
/// A parametric phone stand generator.
/// This example demonstrates complex assembly and coordinate transforms.
///
/// Usage (stdout):
///   moon run --target native examples/28-phone-stand-parametric -- > stand.step
///
/// Usage (write file):
///   moon run --target native examples/28-phone-stand-parametric -- -o stand.step
async fn main {
  let base_args_spec = {
    "phoneThickness": @cli.opt_double(
      12.0,
      help="Thickness of the phone/tablet (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "viewAngle": @cli.opt_double(
      20.0,
      help="Viewing angle from vertical (degrees)",
      min=0.0,
      max=45.0,
    ),
    "width": @cli.opt_double(
      70.0,
      help="Total width of the stand (mm)",
      min=20.0,
    ),
    "height": @cli.opt_double(
      120.0,
      help="Total height of the back support (mm)",
      min=50.0,
    ),
    "thickness": @cli.opt_double(5.0, help="Material thickness (mm)", min=2.0),
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
      prog="28-phone-stand-parametric",
      description="Generate a parametric phone stand.",
    )
    is Some(args) else {
    return
  }
  let phone_t = args.double("phoneThickness")
  let angle = args.double("viewAngle")
  let width = args.double("width")
  let height = args.double("height")
  let t = args.double("thickness")
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

  // Design constants
  let lip_h = 20.0
  let base_l = phone_t + t * 3.0 // space for phone + lip + back support

  // Create side supports
  let side_spacing = width - t
  let left_side = side_support(base_l, lip_h, height, angle, t).map(fn(node) {
    node.translate(x=-side_spacing / 2.0)
  })
  let right_side = side_support(base_l, lip_h, height, angle, t).map(fn(node) {
    node.translate(x=side_spacing / 2.0)
  })

  // Back plate connecting them
  let inner_w = width - 2.0 * t
  let rot = 90.0 - angle
  let back_plate = back_plate(inner_w, height, t, 25.0).rotate_x(rot)

  // Front lip plate
  let front_lip = @cad.Cuboid::new(inner_w, t, lip_h)
    .with_name("front-lip")
    .with_color(@cad.Rgb::new(0.1, 0.2, 0.5))
    .translate(x=-inner_w / 2.0, y=base_l - t, z=0.0)

  // Add branding text on the back plate
  let font = @cad.load_font("baloo")
  let design = @cad.Design::new(name="phone-stand")
    .add_iter(left_side.iter())
    .add_iter(right_side.iter())
    .add(back_plate)
    .add(front_lip)
    .add_text_on_face(
      back_plate,
      "PHONE",
      Top, // In ExtrudedProfile, Top is the Z-end face
      font,
      font_size=10.0,
      emboss_depth=2.0,
      offset_y=height * 0.2, // Move it up
      color=@cad.Rgb::orange(),
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

///|
fn side_support(
  base_l : Double,
  lip_h : Double,
  back_h : Double,
  angle_deg : Double,
  t : Double,
) -> Array[@cad.SceneNode] {
  let color = @cad.Rgb::new(0.2, 0.4, 0.8)
  let rot = 90.0 - angle_deg
  let base = @cad.Cuboid::new(t, base_l, t)
    .with_name("side-base")
    .with_color(color)
  let lip = @cad.Cuboid::new(t, t, lip_h)
    .with_name("side-lip")
    .with_color(color)
    .translate(y=base_l - t)
  let back = @cad.Cuboid::new(t, t, back_h)
    .with_name("side-back")
    .with_color(color)
    .rotate_x(rot)
  [base, lip, back]
}

///|
fn back_plate(
  width : Double,
  height : Double,
  t : Double,
  notch_w : Double,
) -> @cad.SceneNode {
  let hw = width / 2.0
  let nh = height * 0.3
  let nw = notch_w

  // Back plate with notch merged into outer profile
  let outer = [
    (-hw, 0.0),
    (-nw / 2.0, 0.0),
    (-nw / 2.0, nh),
    (nw / 2.0, nh),
    (nw / 2.0, 0.0),
    (hw, 0.0),
    (hw, height),
    (-hw, height),
  ]
  @cad.ExtrudedProfile::new(outer, t)
  .with_name("back-plate")
  .with_color(@cad.Rgb::new(0.3, 0.5, 0.9))
}
