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
    "nowires": @cli.flag(help="Do not build exit wires"),
    "nosupport": @cli.flag(help="Do not build support structure"),
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
    "report": @cli.flag(
      help="Print derived electrical geometry info to stderr (does not affect STEP output)",
    ),
    "rho": @cli.opt_double(
      1.724e-8,
      help="Resistivity in ohm*m for Rdc estimate (default: ~copper at 20C)",
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
    "snapping": @cli.opt_double(
      3.e-3,
      help="Geometric snapping accuracy in millimeters (default: 3.e-3 for 3 microns)",
      min=0,
    ),
    "union": @cli.flag(help="Union wires together and support shapes together"),
    "vertTurns": @cli.opt_double(
      15.0,
      help="Vertical turns of wire in electromagnet",
      min=0,
      min_exclusive=true,
    ),
    "wireGap": @cli.opt_double(
      short='g',
      0.2,
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
    report: args.flag("report"),
    rho: args.double("rho"),
    connector_length: args.double("connector_length"),
    exit_wire_diameter: args.double("exit_wire_diameter"),
    exit_wire_separation: args.double("exit_wire_separation"),
    vert_turns: args.double("vertTurns"),
    debug: args.flag("debug"),
    nocage: args.flag("nocage"),
    nocoil: args.flag("nocoil"),
    nowires: args.flag("nowires"),
    nosupport: args.flag("nosupport"),
    union: args.flag("union"),
    snapping: args.double("snapping"),
  }

  //
  if params.report {
    report_electrical_geometry(params)
  }

  //
  let mut design = @cad.Design::new(
    name="bifilar-electromagnet",
    snapping=params.snapping,
  )
  let wire_nodes = []
  let support_nodes = []
  // Add coil pairs if requested
  if !params.nocoil {
    for pair_num in 1..=params.num_pairs {
      if params.debug {
        @cli.eprintln("Generating pair #\{pair_num} of \{params.num_pairs}")
      }
      let coil_pair = make_coil_pair(pair_num~, params~)
      wire_nodes..push(coil_pair.0).push(coil_pair.1)
    }
  }
  // Add cage if requested
  if !params.nocage {
    let (radius, height) = coil_turn_dimensions(params.num_pairs, params)
    let (wires, support) = make_bfem_cage(
      size=(radius, radius, height),
      params~,
    )
    wire_nodes.append(wires)
    support_nodes.append(support)
  }
  if params.union {
    design = design.add(@cad.union_all(wire_nodes, name="wires"))
    design = design.add(@cad.union_all(support_nodes, name="support"))
  } else {
    for node in wire_nodes {
      design = design.add(node)
    }
    for node in support_nodes {
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
  report : Bool
  rho : Double
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
  nowires : Bool
  nosupport : Bool
  union : Bool
  snapping : Double
}

///|
async fn report_electrical_geometry(params : Params) -> Unit {
  // NOTE: Print only to stderr so stdout remains a clean STEP stream.
  let wire_width_mm = params.wire_width
  let area_mm2 = wire_width_mm * wire_width_mm
  let area_m2 = area_mm2 * 1.0e-6
  let total_helix_length_mm = if params.nocoil {
    0.0
  } else {
    total_bifilar_helix_centerline_length_mm(params)
  }
  let total_helix_length_m = total_helix_length_mm * 1.0e-3
  let rdc_est = if total_helix_length_m == 0.0 {
    0.0
  } else {
    params.rho * total_helix_length_m / area_m2
  }
  @cli.eprintln("bfem:report:wire_width_mm=\{wire_width_mm}")
  @cli.eprintln("bfem:report:area_mm2=\{area_mm2}")
  @cli.eprintln("bfem:report:area_m2=\{area_m2}")
  @cli.eprintln("bfem:report:helix_length_mm=\{total_helix_length_mm}")
  @cli.eprintln("bfem:report:helix_length_m=\{total_helix_length_m}")
  @cli.eprintln("bfem:report:rho_ohm_m=\{params.rho}")
  @cli.eprintln("bfem:report:rdc_est_ohm=\{rdc_est}")
  @cli.eprintln(
    "bfem:report:note=helix-only length; connectors/cage not included",
  )
}

///|
fn total_bifilar_helix_centerline_length_mm(params : Params) -> Double {
  // The model creates two helices per pair (start_angle and start_angle+180).
  // For length purposes, start angle doesn’t matter, so total length is twice
  // the sum of per-pair helix centerline lengths.
  let mut sum = 0.0
  for pair_num in 1..=params.num_pairs {
    sum = sum + coil_helix_centerline_length_mm(pair_num, params)
  }
  2.0 * sum
}

///|
fn coil_helix_centerline_length_mm(pair_num : Int, params : Params) -> Double {
  let (radius, height_per_turn) = coil_turn_dimensions(pair_num, params)
  let start_angle = 180.0 *
    (pair_num.to_double() - 1) /
    params.num_pairs.to_double()
  let path = @cad.helix_path(
    pos=params.pos,
    size_per_turn=(radius, radius, height_per_turn),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  path_length_mm(path.points)
}

///|
fn path_length_mm(points : Array[Vec3]) -> Double {
  if points.length() < 2 {
    return 0.0
  }
  let mut sum = 0.0
  for i in 1..<points.length() {
    sum = sum + vec3_distance(points[i - 1], points[i])
  }
  sum
}

///|
fn vec3_distance(a : Vec3, b : Vec3) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let dz = b.2 - a.2
  (dx * dx + dy * dy + dz * dz).sqrt()
}

///|
fn make_coil_pair(
  pair_num~ : Int,
  params~ : Params,
) -> (@cad.SceneNode, @cad.SceneNode) {
  let delta_z = (params.wire_gap + params.wire_width) /
    (params.num_pairs.to_double() - 1)
  let new_pos = (
    params.pos.0,
    params.pos.1,
    params.pos.2 + (pair_num - 1).to_double() * delta_z,
  )
  let params = { ..params, pos: new_pos }

  //
  let start_angle = 180.0 *
    (pair_num.to_double() - 1) /
    params.num_pairs.to_double()
  // Create the two helices for the bifilar coil pair
  let color = @cad.Rgb::red()
  let coil1 = make_coil(start_angle, pair_num~, params~, color~).with_name(
    "bfem:coil:red:pair-\{pair_num}",
  )
  let color = @cad.Rgb::green()
  let coil2 = make_coil(start_angle + 180, pair_num~, params~, color~).with_name(
    "bfem:coil:green:pair-\{pair_num}",
  )
  return (coil1, coil2)
}

///|
/// coil_turn_dimensions returns the helix path X/Y radius and Z rise per turn
/// for the given coil pair index (1-based).
fn coil_turn_dimensions(pair_num : Int, params : Params) -> (Double, Double) {
  let hw = params.wire_width / 2.0
  let radius = params.inner_diam / 2.0 +
    hw +
    (pair_num - 1).to_double() * (params.wire_gap + params.wire_width)
  let height = 2.0 * (params.wire_width + params.wire_gap)
  return (radius, height)
}

///|
fn square_wire_profile(hw : Double) -> @cad.SweepProfile {
  let wire_pts = [
    (-hw, 0.0, -hw),
    (hw, 0.0, -hw),
    (hw, 0.0, hw),
    (-hw, 0.0, hw),
  ]
  @cad.SweepProfile::new(wire_pts)
}

///|
fn make_coil(
  start_angle : Double,
  pair_num~ : Int,
  params~ : Params,
  color? : @cad.Rgb = @cad.Rgb::red(),
) -> @cad.SceneNode {
  let hw = params.wire_width / 2.0
  let (radius, height) = coil_turn_dimensions(pair_num, params)
  let helix_path = @cad.helix_path(
    pos=params.pos,
    size_per_turn=(radius, radius, height),
    num_turns=params.vert_turns,
    num_segs_per_turn=params.num_segs,
    start_angle~,
  )
  let wire_profile = square_wire_profile(hw)
  let coil_shape = @cad.SweptProfile::new(path=helix_path, profile=wire_profile).with_color(
    color,
  )
  coil_shape
}
