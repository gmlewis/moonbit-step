///|
/// components/examples/makerpipe_frame
///
/// Build a simple rectangular Maker Pipe table frame and print its pipe cut
/// list and connector bill of materials:
///
/// ```bash
/// moon run components/examples/makerpipe_frame -- \
///   --width 1000 --depth 600 --height 800 -o table-frame.step
/// moon run components/examples/makerpipe_frame -- \
///   --size 1 --width 1200 --depth 700 --height 900 --mode assembly \
///   -o table-frame-assembly.step
/// ```
async fn main {
  let spec = {
    "width": @cli.opt_double(
      1000.0,
      help="Overall frame width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "depth": @cli.opt_double(
      600.0,
      help="Overall frame depth in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      800.0,
      help="Overall frame height in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "size": @cli.opt_string(help="Native connector size: 3/4 (default) or 1"),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "schedule": @cli.flag(help="Print the full placed-part schedule"),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/makerpipe_frame",
      description="Build a Maker Pipe table frame with a pipe cut list and BOM.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let depth = args.double("depth")
  let height = args.double("height")
  let size_name = args.string_opt("size").unwrap_or("3/4")
  let size = match @makerpipe.makerpipe_size(size_name) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let cut_list = match
    @makerpipe.table_frame_cut_list(width, depth, height, size) {
    Ok(items) => items
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  @cli.eprintln(
    "Maker Pipe table frame: \{@cad.fmt_double(width, None)} x \{@cad.fmt_double(depth, None)} x \{@cad.fmt_double(height, None)} mm (\{size.trade_size} in EMT)",
  )
  @cli.eprintln("Cut list:")
  for item in cut_list {
    if item.length_mm > 0.0 {
      @cli.eprintln(
        "  \{item.count} x \{item.role}: \{@cad.fmt_double(item.length_mm, Some(2))} mm",
      )
    } else {
      @cli.eprintln("  \{item.count} x \{item.role}")
    }
  }
  let emt = match @motion.emt_size(size.trade_size) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let leg_length = height
  let x_rail_length = width - size.through_pipe_od_mm
  let y_rail_length = depth - size.through_pipe_od_mm
  let leg = match @motion.emt_tube(emt, leg_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let x_rail = match @motion.emt_tube(emt, x_rail_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let y_rail = match @motion.emt_tube(emt, y_rail_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let connector = match @makerpipe.elbow_90(size) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let mut assembly = @assemblies.Assembly::new(
    name="makerpipe-table-frame",
    description="Maker Pipe table frame: four continuous legs, four X rails, four Y rails, and eight 90 degree connectors.",
  )
  let mut counter = 0
  for sx in [-1.0, 1.0] {
    for sy in [-1.0, 1.0] {
      let x = sx * width / 2.0
      let y = sy * depth / 2.0
      let corner = if sx < 0.0 {
        if sy < 0.0 {
          0.0
        } else {
          270.0
        }
      } else if sy < 0.0 {
        90.0
      } else {
        180.0
      }
      counter = counter + 1
      let leg_name = "leg-\{counter}"
      assembly = assembly.add_at(leg, x~, y~, z=0.0, instance_name=leg_name)
      counter = counter + 1
      let bottom_name = "connector-bottom-\{counter}"
      assembly = assembly.add_at(
        connector,
        x~,
        y~,
        z=0.0,
        rz=corner,
        instance_name=bottom_name,
      )
      counter = counter + 1
      let top_name = "connector-top-\{counter}"
      assembly = assembly.add_at(
        connector,
        x~,
        y~,
        z=height,
        rz=corner,
        instance_name=top_name,
      )
    }
  }
  for sy in [-1.0, 1.0] {
    for z in [0.0, height] {
      counter = counter + 1
      let name = "x-rail-\{counter}"
      assembly = assembly.add_at(
        x_rail,
        x=-x_rail_length / 2.0,
        y=sy * depth / 2.0,
        z~,
        ry=90.0,
        instance_name=name,
      )
    }
  }
  for sx in [-1.0, 1.0] {
    for z in [0.0, height] {
      counter = counter + 1
      let name = "y-rail-\{counter}"
      assembly = assembly.add_at(
        y_rail,
        x=sx * width / 2.0,
        y=-y_rail_length / 2.0,
        z~,
        rx=-90.0,
        instance_name=name,
      )
    }
  }
  if args.flag("schedule") {
    @cli.eprintln(assembly.schedule_text())
  }
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
