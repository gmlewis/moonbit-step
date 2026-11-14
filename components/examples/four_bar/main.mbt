///|
/// components/examples/four_bar
///
/// Build a planar four-bar linkage from the linkage kit and the four-bar
/// layout helper:
///
/// ```bash
/// moon run components/examples/four_bar -- \
///   --ground 40 --crank 10 --coupler 40 --rocker 30 --crankAngle 45 \
///   -o four-bar.step
/// moon run components/examples/four_bar -- --mode assembly \
///   -o four-bar-assembly.step
/// ./run-example.sh four_bar --view       # owner
/// ./run-example.sh --headless four_bar    # agents
/// ```
///
/// `four_bar_layout` closes the linkage and gives the joint positions. Each of
/// the four links is placed in its own Z layer with a 1 mm clearance, and each
/// dowel pin spans only the two link layers it joins. This avoids link and pin
/// interpenetration while preserving the planar joint positions. It is a static
/// layout, not a kinematic or contact solver; no strength rating is implied.
async fn main {
  let spec = {
    "ground": @cli.opt_double(
      40.0,
      help="Ground link length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "crank": @cli.opt_double(
      10.0,
      help="Crank length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coupler": @cli.opt_double(
      40.0,
      help="Coupler length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "rocker": @cli.opt_double(
      30.0,
      help="Rocker length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "crankAngle": @cli.opt_double(45.0, help="Crank angle in degrees"),
    "width": @cli.opt_double(
      12.0,
      help="Bar width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      4.0,
      help="Bar thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pivot": @cli.opt_double(
      4.0,
      help="Pivot hole/pin diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/four_bar",
      description="Build a planar four-bar linkage with the four-bar layout helper.",
    )
    is Some(args) else {
    return
  }
  let ground = args.double("ground")
  let crank = args.double("crank")
  let coupler = args.double("coupler")
  let rocker = args.double("rocker")
  let width = args.double("width")
  let thickness = args.double("thickness")
  let pivot = args.double("pivot")
  if width <= pivot {
    @cli.eprintln("error: bar width must exceed the pivot diameter")
    abort("")
  }
  let layout = match
    @mechanisms.four_bar_layout(
      ground,
      crank,
      coupler,
      rocker,
      args.double("crankAngle"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let make_bar = fn(length) {
    match
      @mechanisms.linkage_bar(
        length + width,
        width,
        thickness,
        pivot + 0.2,
        pivot_spacing_mm=length,
      ) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
  }
  let angle_of = fn(dx, dy) { @math.atan2(dy, dx) * 180.0 / @math.PI }
  let ground_bar = make_bar(ground)
  let crank_bar = make_bar(crank)
  let coupler_bar = make_bar(coupler)
  let rocker_bar = make_bar(rocker)
  let crank_dx = layout.crank_joint.0
  let crank_dy = layout.crank_joint.1
  let coupler_dx = layout.rocker_joint.0 - layout.crank_joint.0
  let coupler_dy = layout.rocker_joint.1 - layout.crank_joint.1
  let rocker_dx = layout.rocker_joint.0 - ground
  let rocker_dy = layout.rocker_joint.1
  // Each link is in its own Z layer with a 1 mm clearance, and each pin spans
  // only the two layers it joins. This keeps the flat envelope free of link and
  // pin interpenetration while preserving the planar four-bar joint positions.
  let layer = thickness + 1.0
  let pin_margin = 0.5
  let coupler_z = layer
  let crank_z = 2.0 * layer
  let rocker_z = 3.0 * layer
  let pin_a_length = crank_z + thickness + 2.0 * pin_margin
  let pin_b_length = layer + thickness + 2.0 * pin_margin
  let pin_c_length = 2.0 * layer + thickness + 2.0 * pin_margin
  let pin_d_length = 3.0 * layer + thickness + 2.0 * pin_margin
  let make_pin = fn(length) {
    match @motion.dowel_pin(pivot, length) {
      Ok(c) => c
      Err(e) => abort(e.message())
    }
  }
  let assembly = @assemblies.Assembly::new(
      name="four-bar",
      description="Planar four-bar linkage with each link in its own Z layer and four dowel pins joining the appropriate link layers.",
    )
    .add(
      ground_bar,
      placement=@common.Placement::at(ground / 2.0, 0.0, 0.0),
      instance_name="ground",
    )
    .add(
      coupler_bar,
      placement=@common.Placement::at(
        (layout.crank_joint.0 + layout.rocker_joint.0) / 2.0,
        (layout.crank_joint.1 + layout.rocker_joint.1) / 2.0,
        coupler_z,
        rz=angle_of(coupler_dx, coupler_dy),
      ),
      instance_name="coupler",
    )
    .add(
      crank_bar,
      placement=@common.Placement::at(
        crank_dx / 2.0,
        crank_dy / 2.0,
        crank_z,
        rz=angle_of(crank_dx, crank_dy),
      ),
      instance_name="crank",
    )
    .add(
      rocker_bar,
      placement=@common.Placement::at(
        (ground + layout.rocker_joint.0) / 2.0,
        layout.rocker_joint.1 / 2.0,
        rocker_z,
        rz=angle_of(rocker_dx, rocker_dy),
      ),
      instance_name="rocker",
    )
    .add(
      make_pin(pin_a_length),
      placement=@common.Placement::translation(0.0, 0.0, -pin_margin),
      instance_name="pin-a",
    )
    .add(
      make_pin(pin_b_length),
      placement=@common.Placement::translation(
        layout.crank_joint.0,
        layout.crank_joint.1,
        coupler_z - pin_margin,
      ),
      instance_name="pin-b",
    )
    .add(
      make_pin(pin_c_length),
      placement=@common.Placement::translation(
        layout.rocker_joint.0,
        layout.rocker_joint.1,
        coupler_z - pin_margin,
      ),
      instance_name="pin-c",
    )
    .add(
      make_pin(pin_d_length),
      placement=@common.Placement::translation(ground, 0.0, -pin_margin),
      instance_name="pin-d",
    )
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
