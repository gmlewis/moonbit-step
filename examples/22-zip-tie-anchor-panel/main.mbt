///|
/// 22-zip-tie-anchor-panel
///
/// A working example that generates a STEP model for: A panel of zip-tie
/// anchors with different slot geometries and strengths.
///
/// Usage (stdout):
///   moon run --target native examples/22-zip-tie-anchor-panel -- --rows 2 --cols 3 > anchors.step
async fn main {
  let base_args_spec = {
    "rows": @cli.opt_double(2.0, help="Number of rows of anchors", min=1.0),
    "cols": @cli.opt_double(3.0, help="Number of columns of anchors", min=1.0),
    "spacing": @cli.opt_double(
      25.0,
      help="Spacing between anchors (mm)",
      min=10.0,
    ),
    "baseThickness": @cli.opt_double(
      3.0,
      help="Thickness of the base plate (mm)",
      min=1.0,
    ),
    "anchorWidth": @cli.opt_double(
      12.0,
      help="Outer width of each anchor (mm)",
      min=5.0,
    ),
    "anchorHeight": @cli.opt_double(
      8.0,
      help="Total height of each anchor above base (mm)",
      min=3.0,
    ),
    "slotWidth": @cli.opt_double(
      6.0,
      help="Width of the zip-tie slot (mm)",
      min=1.0,
    ),
    "slotHeight": @cli.opt_double(
      3.0,
      help="Height of the zip-tie slot (mm)",
      min=1.0,
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
  }
  let args_spec = @cli.with_translate(base_args_spec)
  guard @cli.parse(
      args_spec,
      prog="22-zip-tie-anchor-panel",
      description="Generate a zip-tie anchor panel STEP model.",
    )
    is Some(args) else {
    return
  }
  let rows = args.double("rows").to_int()
  let cols = args.double("cols").to_int()
  let spacing = args.double("spacing")
  let base_thickness = args.double("baseThickness")
  let anchor_width = args.double("anchorWidth")
  let anchor_height = args.double("anchorHeight")
  let slot_width = args.double("slotWidth")
  let slot_height = args.double("slotHeight")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = @cad.zip_tie_anchor_panel(
    rows, cols, spacing, base_thickness, anchor_width, anchor_height, slot_width,
    slot_height,
  )
  let mut design = @cad.Design::new(name="zip-tie-anchor-panel")
  let panel_w = Double::from_int(cols) * spacing
  let panel_l = Double::from_int(rows) * spacing
  for node in nodes {
    design = design.add(
      node.translate(x=tx - panel_w / 2.0, y=ty - panel_l / 2.0, z=tz),
    )
  }
  design.write_step(out_path)
}
