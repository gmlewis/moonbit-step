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
    "nocage": @cli.flag(help="Do not add wire cage around electromagnet"),
    "nocoil": @cli.flag(help="Do not build electromagnet"),
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
    "tolerance": @cli.opt_double(0.1, help="Tolerance in millimeters", min=0),
    "connector_length": @cli.opt_double(
      12.0,
      help="Length of connector wires in millimeters",
      min=0,
    ),
    "exit_wire_diameter": @cli.opt_double(
      1.0,
      help="Diameter of exit wires in millimeters",
      min=0,
    ),
    "exit_wire_separation": @cli.opt_double(
      4.0,
      help="Separation of exit wires in millimeters",
      min=0,
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
      0.1,
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
  let pos = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }
  let params = Params::{
    pos,
    inner_diam: args.double("innerDiam"),
    num_pairs: args.int("numPairs"),
    num_segs: args.int("numSegs"),
    out_path: args.string_opt("out"),
    wire_width: args.double("wireWidth"),
    wire_gap: args.double("wireGap"),
    tolerance: args.double("tolerance"),
    back_thickness: args.double("backThickness"),
    front_thickness: args.double("frontThickness"),
    radial_thickness: args.double("radialThickness"),
    connector_length: args.double("connector_length"),
    exit_wire_diameter: args.double("exit_wire_diameter"),
    exit_wire_separation: args.double("exit_wire_separation"),
    vert_turns: args.double("vertTurns"),
    debug: args.flag("debug"),
    nocage: args.flag("nocage"),
    nocoil: args.flag("nocoil"),
  }

  //
  let mut design = @cad.Design::new(name="bifilar-electromagnet")
  // Add coil pairs
  if !params.nocoil {
    for pair_num in 1..=params.num_pairs {
      if params.debug {
        @cli.eprintln("Generating pair #\{pair_num} of \{params.num_pairs}")
      }
      let coil_pair = make_coil_pair(pair_num~, params~)
      design = design.add(coil_pair.0).add(coil_pair.1)
    }
  }
  // Add cage if requested
  if !params.nocage {
    let (radius, height) = calc_radius_height(params.num_pairs - 1, params)
    let nodes = make_bfem_cage(
      pos=params.pos,
      size=(radius, radius, height),
      connector_length=params.connector_length,
      exit_wire_diameter=params.exit_wire_diameter,
      exit_wire_separation=params.exit_wire_separation,
      front_thickness=params.front_thickness,
      back_thickness=params.back_thickness,
      radial_thickness=params.radial_thickness,
      inner_radius=params.inner_diam / 2.0,
      tolerance=params.tolerance,
      turns=params.vert_turns,
      wire_gap=params.wire_gap,
      wire_width=params.wire_width,
      segments=params.num_segs,
      num_pairs=params.num_pairs,
    )
    for node in nodes {
      design = design.add(node)
    }
  }
  design.write_step(params.out_path)
}

///|
struct Params {
  pos : Vec3
  inner_diam : Double
  num_pairs : Int
  num_segs : Int
  out_path : String?
  wire_width : Double
  wire_gap : Double
  tolerance : Double
  connector_length : Double
  exit_wire_diameter : Double
  exit_wire_separation : Double
  back_thickness : Double
  front_thickness : Double
  radial_thickness : Double
  vert_turns : Double
  debug : Bool
  nocage : Bool
  nocoil : Bool
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
fn calc_radius_height(pair_num : Int, params : Params) -> (Double, Double) {
  let hw = params.wire_width / 2.0
  let radius = params.inner_diam / 2.0 +
    hw +
    (pair_num - 1).to_double() * (params.wire_gap + params.wire_width)
  let height = 2.0 * (params.wire_width + params.wire_gap)
  return (radius, height)
}

///|
fn make_coil(
  start_angle : Double,
  pair_num~ : Int,
  params~ : Params,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> @cad.SceneNode {
  let hw = params.wire_width / 2.0
  let (radius, height) = calc_radius_height(pair_num, params)
  let helix_path = @cad.helix_path(
    pos=params.pos,
    size_per_turn=(radius, radius, height),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  let wire_pts = [
    (-hw, 0.0, -hw),
    (hw, 0.0, -hw),
    (hw, 0.0, hw),
    (-hw, 0.0, hw),
  ]
  let wire_profile = @cad.SweepProfile::new(wire_pts)
  let coil_shape = @cad.SweptProfile::new(path=helix_path, profile=wire_profile).with_color(
    color,
  )
  coil_shape
}
