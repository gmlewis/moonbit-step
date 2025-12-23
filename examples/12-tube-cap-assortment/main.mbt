///|
/// 12-tube-cap-assortment
///
/// A parametric tube cap generator. Can create either "caps" (fitting over
/// the outside of a tube) or "plugs" (fitting inside a tube).
///
/// Usage (stdout):
///   moon run --target native examples/12-tube-cap-assortment -- --diameter 20 --wall 1.5 > cap.step
///
/// Usage (write file):
///   moon run --target native examples/12-tube-cap-assortment -- -o cap.step
async fn main {
  let base_args_spec = {
    "diameter": @cli.opt_double(
      25.4,
      help="Target tube diameter (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "wall": @cli.opt_double(
      2.0,
      help="Wall thickness of the cap/plug (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      15.0,
      help="Height of the fitting part (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "topThickness": @cli.opt_double(
      3.0,
      help="Thickness of the cap top (mm)",
      min=0.0,
      min_exclusive=true,
    ),
    "clearance": @cli.opt_double(
      0.2,
      help="Radial clearance for the fit (mm)",
      min=0.0,
    ),
    "type": @cli.opt_string(
      short='t',
      help="Type of fitting: 'cap' (over tube) or 'plug' (inside tube)",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="12-tube-cap-assortment",
      description="Generate a parametric tube cap or plug.",
    )
    is Some(args) else {
    return
  }
  let target_dia = args.double("diameter")
  let wall = args.double("wall")
  let fitting_height = args.double("height")
  let top_thickness = args.double("topThickness")
  let clearance = args.double("clearance")
  let is_plug = args.string_opt("type").unwrap_or("cap") == "plug"
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      abort("")
    }
  }

  //
  // Calculate dimensions based on type
  let (fitting_od, fitting_id, top_dia) = if is_plug {
    // Plug: fits INSIDE tube
    // Fitting OD = Tube ID - clearance
    // Top OD = Tube OD (approx)
    let f_od = target_dia - 2.0 * clearance
    let f_id = f_od - 2.0 * wall
    (f_od, f_id, target_dia + 2.0 * wall)
  } else {
    // Cap: fits OVER tube
    // Fitting ID = Tube OD + clearance
    // Fitting OD = Fitting ID + 2*wall
    let f_id = target_dia + 2.0 * clearance
    let f_od = f_id + 2.0 * wall
    (f_od, f_id, f_od)
  }

  //
  // 1. The Top Plate (solid disk)
  let top = @cad.tube(top_dia, 0.0, top_thickness)
    .with_name("cap-top")
    .with_color(@cad.Rgb::orange())
    .translate(x=tx, y=ty, z=tz + fitting_height)

  //
  // 2. The Fitting Wall (hollow cylinder)
  let wall_part = @cad.tube(fitting_od, fitting_id, fitting_height)
    .with_name("cap-wall")
    .with_color(@cad.Rgb::blue())
    .translate(x=tx, y=ty, z=tz)

  //
  let design = @cad.Design::new(name="tube-cap").add(top).add(wall_part)
  design.write_step(out_path)
}
