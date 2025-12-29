///|
/// 12-bifilar-electromagnet
///
/// Usage (stdout):
///   moon run --target native examples/12-bifilar-electromagnet -- > bifilar-electromagnet.step
///
/// Usage (write file):
///   moon run --target native examples/12-bifilar-electromagnet -- -o bifilar-electromagnet.step
async fn main {
  let base_args_spec = {
    // "addSupport":       @cli.flag("as", false, "Add inner support shaft"),
    "debug": @cli.flag(short='d', help="Turn on debugging info"),
    "innerDiam": @cli.opt_double(
      6.0,
      short='i',
      help="Inner diameter of first coil in millimeters",
      min=0,
      min_exclusive=true,
    ),
    "numPairs": @cli.opt_int(
      10,
      short='p',
      help="Number of coil pairs (minimum 2)",
      min=2,
    ),
    "numSegs": @cli.opt_int(
      36,
      short='s',
      help="Number of segments per 360-degree turn of helix",
      min=3,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a STEP file (default: stdout)",
    ),
    "backThickness": @cli.opt_double(
      short='b',
      1.0,
      help="Back thickness of wires in millimeters",
      min=0,
      min_exclusive=true,
    ),
    "frontThickness": @cli.opt_double(
      short='f',
      1.0,
      help="Front thickness of wires in millimeters",
      min=0,
      min_exclusive=true,
    ),
    "radialThickness": @cli.opt_double(
      short='r',
      1.1,
      help="Radial thickness of outer enclosing connecting wires in millimeters",
      min=0,
      min_exclusive=true,
    ),
    "vertTurns": @cli.opt_double(
      short='t',
      15.0,
      help="Vertical turns of wire in electromagnet",
      min=0,
      min_exclusive=true,
    ),
    "wireGap": @cli.opt_double(
      short='g',
      0.5,
      help="Wire gap in millimeters",
      min=0,
      min_exclusive=true,
    ),
    "wireWidth": @cli.opt_double(
      short='w',
      1.0,
      help="Wire width in millimeters",
      min=0,
      min_exclusive=true,
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="12-bifilar-electromagnet",
      description="Generate a parametric bifilar electromagnet.",
    )
    is Some(args) else {
    return
  }
  let debug = args.flag("debug")
  let inner_diam = args.double("innerDiam")
  let num_pairs = args.int("numPairs")
  let num_segs = args.int("numSegs")
  let out_path = args.string_opt("out")
  let back_thickness = args.double("backThickness")
  let front_thickness = args.double("frontThickness")
  let radial_thickness = args.double("radialThickness")
  let vert_turns = args.double("vertTurns")
  let wire_gap = args.double("wireGap")
  let wire_width = args.double("wireWidth")

  //
  let design = @cad.Design::new(name="bifilar-electromagnet")
  design.write_step(out_path)
}
