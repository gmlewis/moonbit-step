///|
/// 02-calibration-chamfer-block
///
/// A working example that generates a STEP model for a print-tuning block that
/// sweeps chamfers/fillets around the top edge.
///
/// Usage (stdout):
///   moon run --target native examples/02-calibration-chamfer-block -- > block.step
///
/// Usage (write file):
///   moon run --target native examples/02-calibration-chamfer-block -- -o block.step
///
/// Chamfer vs fillet:
/// - If --filletRadius > 0, it takes precedence and we generate a stepped (faceted)
///   fillet-like top profile.
/// - Otherwise, we generate a simple chamfer using --chamferSize.
///
/// Try:
///   moon run --target native examples/02-calibration-chamfer-block -- -o block.step --chamferSize 0.8
///   moon run --target native examples/02-calibration-chamfer-block -- -o block.step --filletRadius 1.2
///   moon run --target native examples/02-calibration-chamfer-block -- -o block.step --length 40 --width 20 --height 10
///
/// Translate examples:
///   moon run --target native examples/02-calibration-chamfer-block -- -t 10,0,0 -o block.step
async fn validate_dims(
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  chamfer_size_mm : Double,
  fillet_radius_mm : Double,
) -> Bool {
  let min_xy = if length_mm < width_mm { length_mm } else { width_mm }
  let min_xy_half = min_xy / 2.0
  if chamfer_size_mm < 0.0 {
    @cli.eprintln("error: --chamferSize must be >= 0")
    return false
  }
  if fillet_radius_mm < 0.0 {
    @cli.eprintln("error: --filletRadius must be >= 0")
    return false
  }
  if chamfer_size_mm > min_xy_half {
    @cli.eprintln("error: --chamferSize is too large for the block footprint")
    return false
  }
  if fillet_radius_mm > min_xy_half {
    @cli.eprintln("error: --filletRadius is too large for the block footprint")
    return false
  }
  if fillet_radius_mm > 0.0 && fillet_radius_mm > height_mm {
    @cli.eprintln("error: --filletRadius must be <= --height")
    return false
  }
  true
}

///|
async fn main {
  let base_args_spec = {
    "length": @cli.opt_double(
      50.0,
      help="Block length (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      20.0,
      help="Block width (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      12.0,
      help="Block height (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "chamferSize": @cli.opt_double(
      1.0,
      help="Top-edge chamfer size (mm). Ignored when --filletRadius > 0.",
      min=0.0,
    ),
    "filletRadius": @cli.opt_double(
      0.0,
      help="Top-edge fillet radius (mm). When > 0, takes precedence over chamfer.",
      min=0.0,
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
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
      prog="02-calibration-chamfer-block",
      description="Generate a chamfer/fillet calibration block STEP model.",
    )
    is Some(args) else {
    return
  }
  let length_mm = args.double("length")
  let width_mm = args.double("width")
  let height_mm = args.double("height")
  let chamfer_size_mm = args.double("chamferSize")
  let fillet_radius_mm = args.double("filletRadius")
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
  if !validate_dims(
      length_mm, width_mm, height_mm, chamfer_size_mm, fillet_radius_mm,
    ) {
    @cli.eprintln("error: invalid dimensions")
    abort("")
  }
  let block = @cad.CalibrationChamferBlock::new(
      length_mm,
      width_mm,
      height_mm,
      chamfer_size_mm~,
      fillet_radius_mm~,
      // This is an internal quality knob; keep the CLI simple.
      fillet_segments=10,
    )
    .with_name("calibration-block")
    .translate(x=tx, y=ty, z=tz)
  let design = @cad.Design::new(name="calibration-chamfer-block").add(block)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}
