///|
/// 11-hex-bit-holder
///
/// A parametric hex bit holder for standard 1/4" (6.35mm) screwdriver bits.
/// Demonstrates using grids of holes and multi-part assemblies (base + holder).
///
/// Usage (stdout):
///   moon run --target native examples/11-hex-bit-holder -- > holder.step
///
/// Usage (write file):
///   moon run --target native examples/11-hex-bit-holder -- -o holder.step
async fn main {
  let base_args_spec = {
    "rows": @cli.opt_double(2.0, help="Number of rows in the grid", min=1.0),
    "cols": @cli.opt_double(4.0, help="Number of columns in the grid", min=1.0),
    "bitDiameter": @cli.opt_double(
      6.35,
      help="Hex bit diameter across flats (mm). Standard is 6.35 (1/4\").",
      min=0.0,
      min_exclusive=true,
    ),
    "tolerance": @cli.opt_double(
      0.15,
      help="Extra clearance for the bit hole (mm)",
      min=0.0,
    ),
    "spacing": @cli.opt_double(
      10.0,
      help="Center-to-center spacing between bits (mm)",
      min=7.5,
    ),
    "height": @cli.opt_double(
      15.0,
      help="Height of the bit holder block (mm)",
      min=2.0,
    ),
    "baseHeight": @cli.opt_double(
      3.0,
      help="Thickness of the solid base plate (mm)",
      min=1.0,
    ),
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
      prog="11-hex-bit-holder",
      description="Generate a parametric hex bit holder.",
    )
    is Some(args) else {
    return
  }
  let rows = args.double("rows").to_int()
  let cols = args.double("cols").to_int()
  let bit_diameter = args.double("bitDiameter")
  let tolerance = args.double("tolerance")
  let spacing = args.double("spacing")
  let holder_height = args.double("height")
  let base_height = args.double("baseHeight")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  //
  let total_width = Double::from_int(cols) * spacing
  let total_length = Double::from_int(rows) * spacing

  // 1. The solid base plate
  let base = @cad.Cuboid::new(total_width, total_length, base_height)
    .with_name("holder-base")
    .with_color(@cad.Rgb::magenta())
    .translate(x=tx, y=ty, z=tz)

  // 2. The holder block with hex holes
  let holder = hex_bit_holder(
      rows,
      cols,
      bit_diameter + tolerance,
      spacing,
      holder_height,
    )
    .with_name("holder-grid")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty, z=tz + base_height)

  //
  let design = @cad.Design::new(name="hex-bit-holder").add(base).add(holder)
  if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn hex_bit_holder(
  rows : Int,
  cols : Int,
  bit_diameter_across_flats : Double,
  spacing : Double,
  height : Double,
) -> @cad.Shape {
  let d = bit_diameter_across_flats / @math.cos(30.0 * @math.PI / 180.0)
  let hex = @cad.Profile2D::polygon(6, d, rotation=30.0)
  let total_width = Double::from_int(cols) * spacing
  let total_length = Double::from_int(rows) * spacing
  let outer = @cad.Profile2D::rect(total_width, total_length)
  let holes = []
  for r in 0..<rows {
    for c in 0..<cols {
      let tx = Double::from_int(c) * spacing + spacing / 2.0
      let ty = Double::from_int(r) * spacing + spacing / 2.0
      holes.push(hex.map(fn(p) { (p.0 + tx, p.1 + ty) }).rev())
    }
  }
  @cad.ExtrudedProfile::new(outer, height, holes~)
}
