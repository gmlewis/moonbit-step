///|
/// 40-face-query-hole
///
/// MakerCad-style relative modeling: compile a block, query its planar faces,
/// pick the upward-facing one, and cut a hole centered on it. The query and
/// placement are deterministic; use `--eval` to have OCCT evaluate the cut
/// into a real, trimmed B-Rep.
///
/// Usage:
///   ./examples/run-example.sh 40 --eval=hole.step --png=hole.png
///   ./examples/run-example.sh 40 -o block.step        # nominal STEP
///
/// Options:
///   --length/-l  Block length in mm (default 40)
///   --width/-w   Block width in mm (default 30)
///   --height     Block height in mm (default 10)
///   --hole/-d    Hole diameter in mm (default 8)
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(
      40.0,
      short='l',
      help="Block length in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      30.0,
      short='w',
      help="Block width in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      10.0,
      help="Block height in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "hole": @cli.opt_double(
      8.0,
      short='d',
      help="Hole diameter in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
  }
  let args_spec = @common.with_output_args(
    base_args_spec,
    out_help="Write STEP output to a file (default: stdout)",
    eval_help="Evaluate the cut with OCCT and write a real trimmed STEP file",
  )
  guard @cli.parse(
      args_spec,
      prog="40-face-query-hole",
      description="Cut a hole into a block's top face discovered by face query.",
    )
    is Some(args) else {
    return
  }
  let length = args.double("length")
  let width = args.double("width")
  let height = args.double("height")
  let hole_diameter = args.double("hole")
  let output = @common.output_paths(args)
  let block = @cad.Cuboid::new(length, width, height)
    .with_name("block")
    .with_color(@cad.Rgb::blue())
  // Query the compiled block's planar faces, keeping the one facing +Z.
  let top = match
    @cad.Design::new(name="probe")
    .add(block)
    .planar_faces()
    .aligned_with((0.0, 0.0, 1.0))
    .sort_by_z(ascending=false)
    .first_matching(fn(_f) { true }) {
    Some(face) => face
    None => {
      @cli.eprintln("error: no upward-facing planar face found")
      abort("")
    }
  }
  // The face frame is the sketch plane: center the hole on the face.
  let center = top.local_xy(top.center())
  let profile = @cad.Profile2D::new(
    @cad.Profile2D::circle(hole_diameter, segments=48),
  )
  let design = @cad.Design::new(
    name="face-query-hole",
    documentation=args.documentation(),
  ).add(
    @cad.cut_on_face(
      block,
      profile,
      top,
      height,
      name="block-with-hole",
      center~,
    ),
  )
  @common.write_output(design, output)
}
