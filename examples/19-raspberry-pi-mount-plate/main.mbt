///|
/// 19-raspberry-pi-mount-plate
///
/// A working example that generates a STEP model for: A mounting plate with
/// programmable hole patterns and cable strain-relief geometry.
///
/// Usage (stdout):
///   moon run --target native examples/19-raspberry-pi-mount-plate -- --width 80 --length 70 > rpi-plate.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(
      85.0,
      help="Width of the mounting plate (mm)",
      min=65.0,
    ),
    "length": @cli.opt_double(
      75.0,
      help="Length of the mounting plate (mm)",
      min=55.0,
    ),
    "thickness": @cli.opt_double(3.0, help="Plate thickness (mm)", min=1.0),
    "holeDiameter": @cli.opt_double(
      3.0,
      help="Mounting hole diameter (mm, RPi standard is 2.75-3.0)",
      min=1.0,
    ),
    "slotLength": @cli.opt_double(
      12.0,
      help="Cable tie slot length (mm)",
      min=5.0,
    ),
    "slotWidth": @cli.opt_double(3.0, help="Cable tie slot width (mm)", min=1.0),
    "bpy": @cli.opt_string(
      help="Write Blender 5.0 Python3 script to a file (instead of STEP)",
    ),
    "blend": @cli.opt_string(help="Create Blender 5.0 file (instead of STEP)"),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="19-raspberry-pi-mount-plate",
      description="Generate a Raspberry Pi mount plate STEP model.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let length = args.double("length")
  let thickness = args.double("thickness")
  let hole_diameter = args.double("holeDiameter")
  let slot_length = args.double("slotLength")
  let slot_width = args.double("slotWidth")
  let blend_path = args.string_opt("blend")
  let bpy_path = args.string_opt("bpy")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let plate = raspberry_pi_mount_plate(
      width, length, thickness, hole_diameter, slot_length, slot_width,
    )
    .with_name("rpi-mount-plate")
    .with_color(@cad.Rgb::green())
    .translate(x=tx - width / 2.0, y=ty - length / 2.0, z=tz)
  let design = @cad.Design::new(name="raspberry-pi-mount-plate").add(plate)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn raspberry_pi_mount_plate(
  width : Double,
  length : Double,
  thickness : Double,
  hole_diameter : Double,
  slot_length : Double,
  slot_width : Double,
) -> @cad.Shape {
  let outer = @cad.Profile2D::rounded_rect(width, length, 3.0)

  // Raspberry Pi standard hole pattern: 58mm x 49mm
  let rpi_w = 58.0
  let rpi_h = 49.0
  let off_x = (width - rpi_w) / 2.0
  let off_y = (length - rpi_h) / 2.0
  let holes = []

  // Mounting holes
  let hole_locs = [
    (off_x, off_y),
    (off_x + rpi_w, off_y),
    (off_x + rpi_w, off_y + rpi_h),
    (off_x, off_y + rpi_h),
  ]
  for loc in hole_locs {
    let (hx, hy) = loc
    holes.push(
      @cad.Profile2D::circle(hole_diameter)
      .map(fn(p) { (p.0 + hx, p.1 + hy) })
      .rev(),
    )
  }

  // Strain relief slots
  // Left slots
  for i in 0..<2 {
    let sy = off_y + 10.0 + Double::from_int(i) * 20.0
    let sx = off_x / 2.0
    let hole = [
      (sx - slot_width / 2.0, sy - slot_length / 2.0),
      (sx + slot_width / 2.0, sy - slot_length / 2.0),
      (sx + slot_width / 2.0, sy + slot_length / 2.0),
      (sx - slot_width / 2.0, sy + slot_length / 2.0),
    ].rev()
    holes.push(hole)
  }
  // Right slots
  for i in 0..<2 {
    let sy = off_y + 10.0 + Double::from_int(i) * 20.0
    let sx = width - off_x / 2.0
    let hole = [
      (sx - slot_width / 2.0, sy - slot_length / 2.0),
      (sx + slot_width / 2.0, sy - slot_length / 2.0),
      (sx + slot_width / 2.0, sy + slot_length / 2.0),
      (sx - slot_width / 2.0, sy + slot_length / 2.0),
    ].rev()
    holes.push(hole)
  }
  @cad.ExtrudedProfile::new(outer, thickness, holes~)
}
