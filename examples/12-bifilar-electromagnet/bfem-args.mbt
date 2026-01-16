///|
/// CLI argument parsing for the BFEM example.
///
/// Kept separate from geometry construction so `main.mbt` stays geometry-focused.

///|
async fn parse_params() -> Params? {
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
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a STEP file (default: stdout)",
    ),
    "nostep": @cli.flag(
      help="Do not write STEP output (neither stdout nor file); useful for pure export/report runs",
    ),
    "export_centerlines": @cli.opt_string(
      help="Write discretized helix centerlines as JSON (for PEEC/FastHenry workflows); does not affect STEP output",
    ),
    "export_conductor_network": @cli.opt_string(
      help="Write a single-series conductor network JSON with explicit IN/OUT terminals (for PEEC/FastHenry workflows); does not affect STEP output",
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
    return None
  }
  let pos = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }
  Some(Params::{
    pos,
    inner_diam: args.double("innerDiam"),
    num_pairs: args.int("numPairs"),
    num_segs: args.int("numSegs"),
    out_path: args.string_opt("out"),
    bpy_path: args.string_opt("bpy"),
    export_centerlines_path: args.string_opt("export_centerlines"),
    export_conductor_network_path: args.string_opt("export_conductor_network"),
    nostep: args.flag("nostep"),
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
  })
}
