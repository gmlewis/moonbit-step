///|
/// 38-planetary-gearbox
///
/// A print-in-place herringbone planetary gearbox. The full parametric
/// algorithm now lives in the `gmlewis/step/components/planetary` component;
/// this example only parses the CLI and writes it.
///
/// `--numElbows 0` builds straight gears as exact line/arc extrusions (the
/// smooth planetary style); the default `--numElbows 4` sweeps the outline
/// through the true helical twist of each elbow as smooth ruled B-spline side
/// surfaces, with sharp piecewise-linear elbow creases.
///
/// Usage (stdout):
///   moon run examples/38-planetary-gearbox -- > gearbox.step
///
/// Usage (write file):
///   ./examples/run-example.sh 38 --numTeeth 12 -o gearbox.step
///
/// Parameter mapping (Go flag -> this program):
///   -mod   --module          -gl  --gearLength      -ha  --helixAngle
///   -hr    --holeRadius      -ht  --holeType        -ne  --numElbows
///   -nt    --numTeeth        -planets --numPlanets  -planetTeeth --planetTeeth
///   -pa    --pressureAngle   -ringTeeth --ringTeeth -tol --tolerance
///   -outerThickness --outerThickness                -res --resolution
///   -o     --out
///   (-obj, -stl, -swapyz, -repo and -debug are mesh-export options and have
///   no STEP equivalent.)

///|
async fn main {
  let base_args_spec = {
    "module": @cli.opt_double(
      3.0,
      short='m',
      help="Gear module (tooth size), see https://www.stlgears.com/theory#module",
    ),
    "gearLength": @cli.opt_double(30.0, short='g', help="Gear length (mm)"),
    "helixAngle": @cli.opt_double(
      30.0,
      short='a',
      help="Helix angle in degrees (clamped to 0..45)",
    ),
    "holeRadius": @cli.opt_double(
      10.0,
      short='r',
      help="Hole minimum radius (mm)",
    ),
    "holeType": @cli.opt_string(
      short='t',
      help="Hole type: None, Squared, Hexagonal, Octagonal, Circular",
    ),
    "numElbows": @cli.opt_int(
      4,
      short='e',
      help="Number of elbows in each herringbone gear (0 = straight exact extrusion)",
    ),
    "numTeeth": @cli.opt_int(
      12,
      short='n',
      help="Number of teeth on the sun gear",
    ),
    "numPlanets": @cli.opt_int(
      3,
      short='p',
      help="Number of orbiting planet gears",
    ),
    "planetTeeth": @cli.opt_int(
      0,
      short='P',
      help="Number of teeth on each planet gear (0 means same as --numTeeth)",
    ),
    "pressureAngle": @cli.opt_double(
      20.0,
      short='A',
      help="Pressure angle in degrees",
    ),
    "ringTeeth": @cli.opt_int(
      0,
      short='R',
      help="Number of teeth on the ring gear (0 means sun + 2*planet)",
    ),
    "tolerance": @cli.opt_double(
      0.25,
      short='T',
      help="Target minimum 3D-printer clearance between meshing flanks (mm)",
    ),
    "outerThickness": @cli.opt_double(
      10.0,
      short='w',
      help="Radial wall thickness from the closest ring notch to the outer surface (mm)",
    ),
    "resolution": @cli.opt_int(
      9,
      short='s',
      help="Number of points in each curved section of the tooth outline",
    ),
    "yUp": @cli.flag(
      help="Keep the native Y-up orientation (gear axes along +Y) instead of rotating the design flat for printing",
    ),
  }
  let args_spec = @common.with_output_args(
    base_args_spec,
    blend=false,
    bpy=false,
  )
  guard @cli.parse(
      args_spec,
      prog="38-planetary-gearbox",
      description="Generate a print-in-place herringbone planetary gearbox.",
    )
    is Some(args) else {
    return
  }
  let params = match
    @planetary.HerringbonePlanetaryParams::new(
      module_mm=args.double("module"),
      gear_length_mm=args.double("gearLength"),
      helix_angle_deg=args.double("helixAngle"),
      pressure_angle_deg=args.double("pressureAngle"),
      num_elbows=args.int("numElbows"),
      resolution=args.int("resolution"),
      hole_type=args.string_opt("holeType").unwrap_or("None"),
      hole_radius_mm=args.double("holeRadius"),
      tolerance_mm=args.double("tolerance"),
      outer_thickness_mm=args.double("outerThickness"),
      sun_teeth=args.int("numTeeth"),
      planet_count=args.int("numPlanets"),
      planet_teeth=args.int("planetTeeth"),
      ring_teeth=args.int("ringTeeth"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let output = @common.output_paths(args)
  let layout = @planetary.herringbone_planetary_layout(params)
  let component = match
    @planetary.herringbone_planetary_gearbox(params, y_up=args.flag("yUp")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if output.step is Some(_) {
    print_layout(layout)
  }
  let design = component.to_design(documentation=args.documentation())
  match @common.select_output(output) {
    @common.WriteStep => {
      @common.write_output(design, output)
      // Keep the always-on connector frames visible next to the STEP file when
      // the wrapper asks for them.
      match (@env.get_env_var("STEP_CONNECTOR_SIDECAR"), output.step) {
        (Some(_), Some(path)) =>
          @step_common.Component::write_connector_sidecar(
            component,
            path + ".connectors.tsv",
          )
        _ => ()
      }
    }
    _ => @common.write_output(design, output)
  }
}

///|
async fn print_layout(layout : @planetary.HerringbonePlanetaryLayout) -> Unit {
  @cli.eprintln(
    "sun:    teeth=\{layout.sun.num_teeth} pitch_radius=\{layout.sun.pitch_radius_mm} base_radius=\{layout.sun.base_radius_mm} root_radius=\{layout.sun.root_radius_mm} outer_radius=\{layout.sun.outer_radius_mm}",
  )
  @cli.eprintln(
    "planet: teeth=\{layout.planet.num_teeth} pitch_radius=\{layout.planet.pitch_radius_mm} base_radius=\{layout.planet.base_radius_mm} root_radius=\{layout.planet.root_radius_mm} outer_radius=\{layout.planet.outer_radius_mm}",
  )
  @cli.eprintln(
    "ring:   teeth=\{layout.ring.num_teeth} pitch_radius=\{layout.ring.pitch_radius_mm} base_radius=\{layout.ring.base_radius_mm} nominal_tooth_tip=\{layout.ring.outer_radius_mm} nominal_notch=\{layout.ring.root_radius_mm}",
  )
  @cli.eprintln(
    "center distance (sun-planet and ring-planet): \{layout.center_distance_mm} (zero-backlash center distance + \{layout.center_delta_mm})",
  )
  @cli.eprintln(
    "target minimum clearance: \{layout.tolerance_mm}, outer thickness: \{layout.outer_thickness_mm}",
  )
  for i, p in layout.planets {
    @cli.eprintln(
      "planet \{i}: pos=(\{p.x}, 0, \{p.z}) rotation=\{p.phi_deg} deg",
    )
  }
  @cli.eprintln(
    "helix angle: \{layout.helix_angle_deg} deg (sun generator: \{layout.helix_angle_sun_deg} deg)",
  )
}
