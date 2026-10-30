///|
/// 41-flange-bolt-circle
///
/// A round flange built with the deterministic Profile2D constraint helpers:
/// a centered outer circle, a central bore, and a bolt circle of holes.
///
/// Usage:
///   ./examples/run-example.sh 41 -o flange.step
///   ./examples/run-example.sh 41 -o flange.step --png=flange.png
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(
      60.0,
      short='d',
      help="Outer flange diameter in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "bore": @cli.opt_double(
      20.0,
      short='b',
      help="Central bore diameter in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "bolt-circle": @cli.opt_double(
      22.0,
      help="Radius of the bolt circle in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "bolts": @cli.opt_int(6, short='n', help="Number of bolt holes", min=1),
    "bolt-hole": @cli.opt_double(
      5.0,
      help="Bolt hole diameter in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      8.0,
      short='t',
      help="Flange thickness in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
  }
  let args_spec = @common.with_output_args(
    base_args_spec,
    out_help="Write STEP output to a file (default: stdout)",
  )
  guard @cli.parse(
      args_spec,
      prog="41-flange-bolt-circle",
      description="Generate a flanged plate with a bolt circle.",
    )
    is Some(args) else {
    return
  }
  let diameter = args.double("diameter")
  let bore = args.double("bore")
  let bolt_radius = args.double("bolt-circle")
  let bolts = args.int("bolts")
  let bolt_hole = args.double("bolt-hole")
  let thickness = args.double("thickness")
  let output = @common.output_paths(args)
  // Concrete coordinates: no solver runs at export time.
  let profile = @cad.Profile2D::new(
      @cad.Profile2D::centered_circle(diameter, segments=96),
    )
    .with_hole_at(0.0, 0.0, bore, segments=48)
    .with_bolt_circle(bolts, bolt_radius, bolt_hole, segments=24)
  let design = @cad.Design::new(
    name="flange-bolt-circle",
    documentation=args.documentation(),
  ).add(
    @cad.ExtrudedProfile::new(profile.outer, thickness, holes=profile.holes)
    .with_name("flange")
    .with_color(@cad.Rgb::blue()),
  )
  @common.write_output(design, output)
}
