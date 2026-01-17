///|
/// 01-hello-cube
///
/// A small example that generates a cube STEP model.
///
/// Usage (stdout):
///   moon run --target native examples/01-hello-cube -- --edge 20 > cube.step
///
/// Usage (write file):
///   moon run --target native examples/01-hello-cube -- -o cube.step --edge 30
///   # also supported: --out=cube.step
///
/// Translate examples:
///   moon run --target native examples/01-hello-cube -- -t 1 2 3
///   moon run --target native examples/01-hello-cube -- -t 1,2,3
///   moon run --target native examples/01-hello-cube -- --translate="1 2 3"
///   moon run --target native examples/01-hello-cube -- --tx 1 --ty 2 --tz 3
async fn main {
  let base_args_spec = {
    "edge": @cli.opt_double(
      20.0,
      short='e',
      help="Edge length in millimeters",
      min=0.0,
      min_exclusive=true,
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write STEP output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="01-hello-cube",
      description="Generate a cube STEP model.",
    )
    is Some(args) else {
    return
  }
  let edge_mm = args.double("edge")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }
  let design = @cad.Design::new(name="hello-cube").add(
    @cad.Cuboid::new(edge_mm, edge_mm, edge_mm)
    .with_name("cube")
    .with_color(@cad.Rgb::green())
    .translate(x=tx, y=ty, z=tz),
  )
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
