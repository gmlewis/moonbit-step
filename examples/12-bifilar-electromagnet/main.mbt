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
      help="Back thickness of wires in millimeters for wire cage",
      min=0,
      min_exclusive=true,
    ),
    "frontThickness": @cli.opt_double(
      short='f',
      1.0,
      help="Front thickness of wires in millimeters for wire cage",
      min=0,
      min_exclusive=true,
    ),
    "radialThickness": @cli.opt_double(
      short='r',
      1.1,
      help="Radial thickness of outer enclosing connecting wires in millimeters for wire cage",
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
  let params = Params::{
    inner_diam: args.double("innerDiam"),
    num_pairs: args.int("numPairs"),
    num_segs: args.int("numSegs"),
    out_path: args.string_opt("out"),
    wire_width: args.double("wireWidth"),
    wire_gap: args.double("wireGap"),
    back_thickness: args.double("backThickness"),
    front_thickness: args.double("frontThickness"),
    radial_thickness: args.double("radialThickness"),
    vert_turns: args.double("vertTurns"),
    debug: args.flag("debug"),
  }

  //
  let mut design = @cad.Design::new(name="bifilar-electromagnet")
  for pair_num in 1..=params.num_pairs {
    if params.debug {
      @cli.eprintln("Generating pair #\{pair_num} of \{params.num_pairs}")
    }
    let coil_pair = make_coil_pair(pair_num~, params~)
    design = design.add(coil_pair.0).add(coil_pair.1)
  }
  design.write_step(params.out_path)
}

///|
struct Params {
  inner_diam : Double
  num_pairs : Int
  num_segs : Int
  out_path : String?
  wire_width : Double
  wire_gap : Double
  back_thickness : Double
  front_thickness : Double
  radial_thickness : Double
  vert_turns : Double
  debug : Bool
}

///|
fn make_coil_pair(
  pair_num~ : Int,
  params~ : Params,
) -> (@cad.SceneNode, @cad.SceneNode) {
  let start_angle = 180.0 *
    (pair_num.to_double() - 1) /
    params.num_pairs.to_double()
  // Create the two helices for the bifilar coil pair
  let coil1 = make_coil(start_angle, pair_num~, params~).with_name(
    "coil-1-pair-\{pair_num}",
  )
  let coil2 = make_coil(start_angle + 180, pair_num~, params~).with_name(
    "coil-2-pair-\{pair_num}",
  )
  return (coil1, coil2)
}

///|
fn make_coil(
  start_angle : Double,
  pair_num~ : Int,
  params~ : Params,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> @cad.SceneNode {
  let pos = (0.0, 0.0, 0.0)
  let radius = params.inner_diam +
    (pair_num - 1).to_double() *
    (2.0 * params.radial_thickness + params.wire_gap * 2.0 + params.wire_width)
  let height = params.vert_turns * (params.wire_width + params.wire_gap) * 2.0
  let helix_path = @cad.helix_path(
    pos~,
    size=(radius, radius, height),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  let hw = params.wire_width / 2.0
  let wire_profile = [
    (-hw, -hw, 0.0),
    (hw, -hw, 0.0),
    (hw, hw, 0.0),
    (-hw, hw, 0.0),
  ]
  let coil_shape = @cad.Sweep::new(path=helix_path, profile=wire_profile).with_color(
    color,
  )
  coil_shape
}
