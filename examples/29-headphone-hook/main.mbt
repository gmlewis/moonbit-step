///|
/// 29-headphone-hook
///
/// A parametric wall-mounted headphone hook.
/// Demonstrates profile construction with computed fillets for strength
/// and aesthetics.
///
/// Usage (stdout):
///   moon run --target native examples/29-headphone-hook -- > hook.step
///
/// Usage (write file):
///   moon run --target native examples/29-headphone-hook -- -o hook.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(30.0, help="Width of the hook (mm)", min=10.0),
    "armLength": @cli.opt_double(
      60.0,
      help="Length of the horizontal arm (mm)",
      min=20.0,
    ),
    "hookHeight": @cli.opt_double(
      25.0,
      help="Height of the front retaining lip (mm)",
      min=10.0,
    ),
    "mountHeight": @cli.opt_double(
      50.0,
      help="Height of the mounting plate (mm)",
      min=20.0,
    ),
    "thickness": @cli.opt_double(
      6.0,
      help="Main material thickness (mm)",
      min=2.0,
    ),
    "filletRadius": @cli.opt_double(
      8.0,
      help="Radius of the inner fillets (mm)",
      min=0.0,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="29-headphone-hook",
      description="Generate a parametric headphone hook.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let arm_l = args.double("armLength")
  let hook_h = args.double("hookHeight")
  let mount_h = args.double("mountHeight")
  let t = args.double("thickness")
  let r = args.double("filletRadius")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  // Create the main hook body
  // Profile in XY: X=depth, Y=height.
  // We rotate it 90 deg on X so Height(Y) -> Z (UP), and Extrusion(Z) -> -Y (Width).
  let hook = main_hook_body(width, arm_l, hook_h, mount_h, t, r).rotate_x(90.0)

  // Add a reinforcing rib in the middle
  let rib_t = t / 2.0
  let rib = reinforcing_rib(mount_h, t, rib_t)
    .rotate_x(90.0)
    .translate(y=-(width - rib_t) / 2.0)

  // Add branding text on the side
  // Side face is at Y = 0 (after hook rotation).
  let font = @baloo.font
  let brand_text = @cad.text_at(
    "STUDIO",
    t + (arm_l - t) * 0.5,
    0.0,
    t * 0.5, // x (depth), y (face), z (height)
    font~,
    font_size=t * 0.8,
    emboss_depth=1.0,
    rx=-90.0,
  ).map(fn(node) { node.with_color(@cad.Rgb::orange()) })
  let design = @cad.Design::new(name="headphone-hook")
    .add(hook)
    .add(rib)
    .add_iter(brand_text.iter())
    .rotate_z(180.0) // Better viewing angle
    .translate(x=tx, y=ty, z=tz)
  design.write_step(out_path)
}

///|
fn main_hook_body(
  width : Double,
  arm_l : Double,
  hook_h : Double,
  mount_h : Double,
  t : Double,
  r : Double,
) -> @cad.SceneNode {
  let pts = []

  // Profile in XY plane (X=depth, Y=height)
  // CCW order
  pts.push((0.0, 0.0)) // 1. Origin (back bottom)
  pts.push((arm_l, 0.0)) // 2. Front bottom
  pts.push((arm_l, hook_h)) // 3. Front top outer
  pts.push((arm_l - t, hook_h)) // 4. Front top inner

  // 5. Front bottom inner elbow (CW arc for concave corner)
  let c2 = (arm_l - t - r, t + r)
  pts.push_iter(
    @cad.Profile2D::arc(2.0 * r, 0.0, -0.5 * @math.PI, segments=8)
    .iter()
    .map(fn(p) { (p.0 + c2.0, p.1 + c2.1) }),
  )

  // 6. Back bottom inner elbow (CW arc for concave corner)
  let c1 = (t + r, t + r)
  pts.push_iter(
    @cad.Profile2D::arc(2.0 * r, 1.5 * @math.PI, @math.PI, segments=8)
    .iter()
    .map(fn(p) { (p.0 + c1.0, p.1 + c1.1) }),
  )
  pts.push((t, mount_h)) // 7. Back top inner
  pts.push((0.0, mount_h)) // 8. Back top outer

  // Extrude along Z (width)
  @cad.ExtrudedProfile::new(pts, width)
  .with_name("headphone-hook")
  .with_color(@cad.Rgb::new(0.4, 0.2, 0.6))
}

///|
fn reinforcing_rib(
  mount_h : Double,
  t : Double,
  rib_t : Double,
) -> @cad.SceneNode {
  // A simple triangular gusset for strength
  let profile = [(t, t), (t + mount_h * 0.5, t), (t, t + mount_h * 0.5)]
  @cad.ExtrudedProfile::new(profile, rib_t)
  .with_name("rib")
  .with_color(@cad.Rgb::new(0.3, 0.1, 0.5))
}
