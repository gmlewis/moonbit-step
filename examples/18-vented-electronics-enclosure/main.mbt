///|
/// 18-vented-electronics-enclosure
///
/// A working example that generates a STEP model for: A vented box generator:
/// walls, lid, screw bosses, and parametric vent patterns.
///
/// Usage (stdout):
///   moon run --target native examples/18-vented-electronics-enclosure -- --width 80 --length 120 --height 40 > enclosure.step
async fn main {
  let base_args_spec = {
    "width": @cli.opt_double(80.0, help="Outer width of the box (mm)", min=20.0),
    "length": @cli.opt_double(
      120.0,
      help="Outer length of the box (mm)",
      min=20.0,
    ),
    "height": @cli.opt_double(
      40.0,
      help="Total height of the box body (mm)",
      min=5.0,
    ),
    "wallThickness": @cli.opt_double(
      2.5,
      help="Thickness of the walls (mm)",
      min=1.0,
    ),
    "filletRadius": @cli.opt_double(
      5.0,
      help="Corner fillet radius (mm)",
      min=0.0,
    ),
    "bossOD": @cli.opt_double(
      8.0,
      help="Screw boss outer diameter (mm)",
      min=1.0,
    ),
    "bossID": @cli.opt_double(
      3.2,
      help="Screw boss inner (hole) diameter (mm)",
      min=0.5,
    ),
    "lidThickness": @cli.opt_double(
      3.0,
      help="Thickness of the lid (mm)",
      min=1.0,
    ),
    "ventWidth": @cli.opt_double(2.0, help="Width of vent slots (mm)", min=0.5),
    "ventSpacing": @cli.opt_double(
      4.0,
      help="Spacing between vent slots (mm)",
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
      prog="18-vented-electronics-enclosure",
      description="Generate a vented electronics enclosure STEP model.",
    )
    is Some(args) else {
    return
  }
  let width = args.double("width")
  let length = args.double("length")
  let height = args.double("height")
  let wall_thickness = args.double("wallThickness")
  let fillet_radius = args.double("filletRadius")
  let boss_od = args.double("bossOD")
  let boss_id = args.double("bossID")
  let lid_thickness = args.double("lidThickness")
  let vent_width = args.double("ventWidth")
  let vent_spacing = args.double("ventSpacing")
  let out_path = args.string_opt("out")
  let (tx, ty, tz) = match args.translate_xyz() {
    Some(v) => v
    None => {
      @cli.eprintln("error: invalid translation")
      return
    }
  }
  let nodes = vented_enclosure(
    width,
    length,
    height,
    wall_thickness,
    fillet_radius,
    boss_od,
    boss_id,
    lid_thickness,
    vent_slot_width=vent_width,
    vent_slot_spacing=vent_spacing,
  )
  let mut design = @cad.Design::new(name="vented-enclosure")
  for node in nodes {
    design = design.add(
      node.translate(x=tx - width / 2.0, y=ty - length / 2.0, z=tz),
    )
  }
  design.write_step(out_path)
}

///|
fn vented_enclosure(
  width : Double,
  length : Double,
  height : Double,
  wall_thickness : Double,
  fillet_radius : Double,
  boss_diameter : Double,
  boss_hole_diameter : Double,
  lid_thickness : Double,
  vent_slot_width? : Double = 2.0,
  vent_slot_spacing? : Double = 4.0,
) -> Array[@cad.SceneNode] {
  let outer = @cad.Profile2D::rounded_rect(width, length, fillet_radius)
  let inner_r = if fillet_radius > wall_thickness {
    fillet_radius - wall_thickness
  } else {
    0.0
  }
  let inner = @cad.Profile2D::rounded_rect(
      width - 2.0 * wall_thickness,
      length - 2.0 * wall_thickness,
      inner_r,
    )
    .map(fn(p) { (p.0 + wall_thickness, p.1 + wall_thickness) })
    .rev()

  // 1. Body Bottom
  let bottom = @cad.ExtrudedProfile::new(outer, wall_thickness)
    .with_name("body-bottom")
    .with_color(@cad.Rgb::blue())

  // 2. Body Walls
  let walls = @cad.ExtrudedProfile::new(outer, height - wall_thickness, holes=[
      inner,
    ])
    .with_name("body-walls")
    .with_color(@cad.Rgb::blue())
    .translate(z=wall_thickness)
  let nodes = [bottom, walls]

  // 3. Screw Bosses
  let boss_h = height - wall_thickness
  let boss_offset = wall_thickness + boss_diameter / 2.0
  let boss_locs = [
    (boss_offset, boss_offset),
    (width - boss_offset, boss_offset),
    (width - boss_offset, length - boss_offset),
    (boss_offset, length - boss_offset),
  ]
  for i, loc in boss_locs {
    let (bx, by) = loc
    let boss = @cad.tube(boss_diameter, boss_hole_diameter, boss_h)
      .with_name("boss-\{i}")
      .with_color(@cad.Rgb::cyan())
      .translate(x=bx, y=by, z=wall_thickness)
    nodes.push(boss)
  }

  // 4. Lid with Vents
  let vent_w = vent_slot_width
  let vent_s = vent_slot_spacing
  let lid_holes = []

  // Add some vent slots in the middle
  let safe_margin = wall_thickness + boss_diameter + 2.0
  let vent_area_w = width - 2.0 * safe_margin
  let vent_area_l = length - 2.0 * safe_margin
  if vent_area_w > vent_w && vent_area_l > vent_w {
    let num_vents = (vent_area_w / vent_s).to_int()
    for i in 0..<num_vents {
      let vx = safe_margin + Double::from_int(i) * vent_s
      let hole = [
        (vx - vent_w / 2.0, safe_margin),
        (vx + vent_w / 2.0, safe_margin),
        (vx + vent_w / 2.0, safe_margin + vent_area_l),
        (vx - vent_w / 2.0, safe_margin + vent_area_l),
      ].rev()
      lid_holes.push(hole)
    }
  }

  // Add screw holes to lid
  for loc in boss_locs {
    let (bx, by) = loc
    let hole = @cad.Profile2D::circle(boss_hole_diameter)
      .map(fn(p) { (p.0 + bx, p.1 + by) })
      .rev()
    lid_holes.push(hole)
  }
  let lid = @cad.ExtrudedProfile::new(outer, lid_thickness, holes=lid_holes)
    .with_name("lid")
    .with_color(@cad.Rgb::orange())
    .translate(z=height + 10.0) // Exploded view
  nodes.push(lid)
  nodes
}
