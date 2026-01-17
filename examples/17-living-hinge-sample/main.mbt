///|
/// 17-living-hinge-sample
///
/// A working example that generates a STEP model for a living hinge sample.
///
/// Usage (stdout):
///   moon run --target native examples/17-living-hinge-sample -- --thickness 2 > hinge.step
async fn main {
  let base_args_spec = {
    "plateLength": @cli.opt_double(
      30.0,
      help="Length of the solid plates on either side (mm)",
      min=1.0,
    ),
    "width": @cli.opt_double(
      50.0,
      help="Total width of the hinge (mm)",
      min=1.0,
    ),
    "thickness": @cli.opt_double(2.0, help="Material thickness (mm)", min=0.1),
    "hingeWidth": @cli.opt_double(
      20.0,
      help="Width of the slotted hinge section (mm)",
      min=1.0,
    ),
    "slotWidth": @cli.opt_double(1.0, help="Width of each slot (mm)", min=0.1),
    "slotLength": @cli.opt_double(
      10.0,
      help="Length of each slot (mm)",
      min=1.0,
    ),
    "numRows": @cli.opt_double(7.0, help="Number of rows of slots", min=1.0),
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
      prog="17-living-hinge-sample",
      description="Generate a living hinge sample STEP model.",
    )
    is Some(args) else {
    return
  }
  let plate_length = args.double("plateLength")
  let width = args.double("width")
  let thickness = args.double("thickness")
  let hinge_width = args.double("hingeWidth")
  let slot_width = args.double("slotWidth")
  let slot_length = args.double("slotLength")
  let num_rows = args.double("numRows").to_int()
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
  let hinge = living_hinge(
      plate_length, width, thickness, hinge_width, slot_width, slot_length, num_rows,
    )
    .with_name("living-hinge")
    .with_color(@cad.Rgb::purple())
    .translate(x=tx, y=ty, z=tz)
  let design = @cad.Design::new(name="living-hinge-sample").add(hinge)
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
fn living_hinge(
  plate_length : Double,
  total_width : Double,
  thickness : Double,
  hinge_width : Double,
  slot_width : Double,
  slot_length : Double,
  num_rows : Int,
) -> @cad.Shape {
  let total_length = 2.0 * plate_length + hinge_width
  let outer = @cad.Profile2D::rect(total_length, total_width)
  let holes = []
  let row_spacing = hinge_width / Double::from_int(num_rows + 1)
  for i in 0..<num_rows {
    let row_x = plate_length + Double::from_int(i + 1) * row_spacing
    let is_offset = i % 2 == 1

    // Number of slots in this row
    let mut current_y = if is_offset { -slot_length / 2.0 } else { 0.0 }
    let spacing_y = slot_length * 1.2
    let padding = 1.0
    while current_y < total_width + slot_length {
      let y_start = if current_y < padding { padding } else { current_y }
      let y_end = if current_y + slot_length > total_width - padding {
        total_width - padding
      } else {
        current_y + slot_length
      }
      if y_end - y_start > 1.0 { // Minimum slot length
        let sw = slot_width
        let hole = [
          (row_x - sw / 2.0, y_start),
          (row_x + sw / 2.0, y_start),
          (row_x + sw / 2.0, y_end),
          (row_x - sw / 2.0, y_end),
        ].rev()
        holes.push(hole)
      }
      current_y = current_y + spacing_y
    }
  }
  @cad.ExtrudedProfile::new(outer, thickness, holes~)
}
