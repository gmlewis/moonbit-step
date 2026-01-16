///|
/// 36-chronos-gear-flower
///
/// A high-detail model that demonstrates the power of parametric
/// modeling. It features radial symmetry, complex profiles,
/// and multiple colors.
///
/// Usage (stdout):
///   moon run --target native examples/36-chronos-gear-flower -- > flower.step
///
/// Usage (write file):
///   moon run --target native examples/36-chronos-gear-flower -- -o flower.step
async fn main {
  let base_args_spec = {
    "petals": @cli.opt_int(12, help="Number of petals", min=3, max=36),
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
      prog="36-chronos-gear-flower",
      description="Generate a Chronos Gear-Flower model.",
    )
    is Some(args) else {
    return
  }
  let num_petals = args.int("petals")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => (0.0, 0.0, 0.0)
  }
  let design = @cad.Design::new(name="chronos-gear-flower")

  // 1. Central Hub - Tiered "Reactor Core"
  // Outer Ring (lowest)
  let hub_outer_h = 8.0
  let hub_outer = @cad.tube(34.0, 28.0, hub_outer_h)
    .with_name("hub-outer")
    .with_color(@cad.Rgb::new(0.0, 0.2, 0.5)) // Deep Space Blue

  // Middle Ring (mid height)
  let hub_mid_h = 12.0
  let hub_mid = @cad.tube(26.0, 20.0, hub_mid_h)
    .with_name("hub-mid")
    .with_color(@cad.Rgb::cyan())

  // Inner Core (tallest) - Enlarged for better text visibility
  let hub_core_h = 16.0
  let hub_core = @cad.tube(18.0, 0.0, hub_core_h)
    .with_name("hub-core")
    .with_color(@cad.Rgb::magenta())
  let mut design = design.add(hub_outer).add(hub_mid).add(hub_core)

  // 2. Petals - Parametric sweeping shapes with "Propeller" rotation
  for i in 0..<num_petals {
    let angle = Double::from_int(i) * 360.0 / Double::from_int(num_petals)

    // Alternating colors for depth
    let color = if i % 2 == 0 {
      @cad.Rgb::new(0.6, 0.0, 0.8) // Royal Purple
    } else {
      @cad.Rgb::new(0.8, 0.0, 0.6) // Deep Magenta
    }

    // Restoration of wider organic petal profile
    let outer_pts = [
      (0.0, -2.0),
      (15.0, -6.0),
      (40.0, -18.0),
      (70.0, -22.0),
      (90.0, -10.0),
      (100.0, 0.0),
      (90.0, 10.0),
      (70.0, 22.0),
      (40.0, 18.0),
      (15.0, 6.0),
      (0.0, 2.0),
    ]

    // Slotted cutout
    let hole_pts = [
      (20.0, -3.0),
      (50.0, -10.0),
      (80.0, -5.0),
      (85.0, 0.0),
      (80.0, 5.0),
      (50.0, 10.0),
      (20.0, 3.0),
    ].rev()
    let petal = @cad.ExtrudedProfile::new(outer_pts, 2.0, holes=[hole_pts])
      .with_name("petal-\{i}")
      .with_color(color)
      // "Propeller Pitch": Rotate around the longitudinal (X) axis
      .rotate_x(35.0)
      // Tilt UPWARD slightly
      .rotate_y(-15.0)
      .rotate_z(angle)
      .translate(z=4.0)
    design = design.add(petal)

    // Inner "Power Blade" - shorter, counter-pitched
    let blade_pts = [
      (0.0, -1.5),
      (20.0, -4.0),
      (45.0, 0.0),
      (20.0, 4.0),
      (0.0, 1.5),
    ]
    let blade = @cad.ExtrudedProfile::new(blade_pts, 1.5)
      .with_name("blade-\{i}")
      .with_color(@cad.Rgb::cyan())
      .rotate_x(-35.0) // Opposite pitch
      .rotate_y(-25.0) // Steeper tilt
      .rotate_z(angle + 180.0 / Double::from_int(num_petals))
      .translate(z=hub_mid_h - 1.0)
    design = design.add(blade)
  }

  // 3. Filaments - Floating energy emitters, leaning outward to clear text
  let num_filaments = 6
  let filament_radius = 8.0
  for i in 0..<num_filaments {
    let angle = Double::from_int(i) * 360.0 / Double::from_int(num_filaments) +
      30.0
    let rad = angle * @math.PI / 180.0
    let fx = filament_radius * @math.cos(rad)
    let fy = filament_radius * @math.sin(rad)

    // Slanted filament rod leaning OUTWARD (65 degrees tilt)
    let filament = @cad.tube(1.5, 0.0, 35.0)
      .with_name("filament-\{i}")
      .with_color(@cad.Rgb::white())
      .rotate_x(65.0)
      .rotate_z(angle)
      .translate(x=fx, y=fy, z=hub_core_h - 2.0)

    // Tip "Emitter"
    let (lx, ly, lz) = @cad.rotate_point((0.0, 0.0, 35.0), 65.0, 0.0, angle)
    let emitter = @cad.tube(5.0, 2.5, 5.0)
      .with_name("emitter-\{i}")
      .with_color(@cad.Rgb::orange())
      .rotate_x(65.0)
      .rotate_z(angle)
      .translate(x=fx + lx, y=fy + ly, z=hub_core_h - 2.0 + lz)
    design = design.add(filament).add(emitter)
  }

  // 4. Branding - High-contrast text on the Core
  let font = @cad.load_font("baloo")
  design = design.add_text_on_face(
    hub_core,
    "CHRONOS",
    Top,
    font,
    color=@cad.Rgb::white(),
    margin=2.0,
    emboss_depth=1.5,
  )
  design = design.translate(x=tx, y=ty, z=tz)
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
