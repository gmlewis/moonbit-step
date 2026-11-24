///|
/// 39-axial-snap-fit
///
/// Print-ready test pair demonstrating `@fasteners.AxialSnapPinParams`:
/// two concentric Ø32 x 7 mm test pucks (simulating two stacked gears with
/// an 8 mm center bore) joined by N support-free 45-degree revolved split
/// snap-fit connectors.
///
/// Left puck (x = -20 mm): base puck with N positive cross-slotted male snap
/// pins protruding upward (+Z).
/// Right puck (x = +20 mm): mating puck with N matching female 45-degree
/// undercut sockets cut from the bed face (+Z), verifying support-free
/// printing in both orientations.

///|
async fn main {
  let spec = {
    "count": @cli.opt_int(
      3,
      help="Number of snap-fit pins on the bolt circle (3–6, default 3)",
      min=1,
    ),
    "bcd": @cli.opt_double(
      20.0,
      help="Bolt circle diameter for snap pins in mm (default 20.0)",
      min=8.0,
    ),
    "puckDiam": @cli.opt_double(
      32.0,
      help="Test puck outer diameter in mm (default 32.0)",
      min=16.0,
    ),
    "puckHeight": @cli.opt_double(
      7.0,
      help="Test puck thickness in mm (default 7.0)",
      min=4.0,
    ),
    "boreDiam": @cli.opt_double(
      8.0,
      help="Central shaft bore diameter in mm (default 8.0)",
      min=0.0,
    ),
    "baseRadius": @cli.opt_double(
      3.0,
      help="Snap pin base radius at mating face in mm (default 3.0)",
      min=1.0,
    ),
    "neckRadius": @cli.opt_double(
      2.5,
      help="Snap pin neck radius in mm (default 2.5)",
      min=0.8,
    ),
    "neckHeight": @cli.opt_double(
      4.0,
      help="Snap pin neck height in mm (default 4.0)",
      min=1.5,
    ),
    "undercut": @cli.opt_double(
      0.30,
      help="Radial barb undercut in mm (default 0.30)",
      min=0.05,
    ),
    "tipRadius": @cli.opt_double(
      1.8,
      help="Flat tip radius in mm (default 1.8)",
      min=0.5,
    ),
    "clearance": @cli.opt_double(
      0.10,
      help="Radial clearance between male pin and female void in mm (default 0.10)",
      min=0.0,
    ),
    "slots": @cli.opt_int(
      2,
      help="Number of vertical flex slots (mandatory >= 1; 1=split, 2=cross, default 2)",
      min=1,
    ),
    "slotWidth": @cli.opt_double(
      0.9,
      help="Vertical flex slot width in mm (default 0.9)",
      min=0.3,
    ),
    "out": @cli.opt_string(
      help="Output evaluated STEP path (default /tmp/39-axial-snap-fit.step)",
      short='o',
    ),
  }
  guard @cli.parse(
      spec,
      prog="39-axial-snap-fit",
      description="Support-free 45-degree revolved axial snap-fit test pair.",
    )
    is Some(args) else {
    return
  }

  let count = args.int("count")
  let bcd = args.double("bcd")
  let puck_diam = args.double("puckDiam")
  let puck_h = args.double("puckHeight")
  let bore_diam = args.double("boreDiam")
  let out_path = args.string_opt("out").unwrap_or("/tmp/39-axial-snap-fit.step")

  let params = match
    @fasteners.AxialSnapPinParams::new(
      base_radius_mm=args.double("baseRadius"),
      neck_radius_mm=args.double("neckRadius"),
      neck_height_mm=args.double("neckHeight"),
      undercut_mm=args.double("undercut"),
      tip_radius_mm=args.double("tipRadius"),
      clearance_mm=args.double("clearance"),
      num_slots=args.int("slots"),
      slot_width_mm=args.double("slotWidth"),
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }

  let positions = @fasteners.axial_snap_ring_positions(count, bcd / 2.0)
  let spacing = puck_diam / 2.0 + 4.0

  // Helper to build a test puck with a 0.35 mm bottom elephant-foot chamfer.
  // RevolvedProfile::chamfered_tube / chamfered_cylinder take outer/inner diameters.
  let make_puck_blank = fn(label : String, color : @cad.Rgb) -> @cad.SceneNode {
    let body = if bore_diam > 0.5 {
      @cad.RevolvedProfile::chamfered_tube(
        puck_diam,
        bore_diam,
        puck_h,
        outer_bottom_chamfer=0.35,
        inner_bottom_chamfer=0.35,
      )
    } else {
      @cad.RevolvedProfile::chamfered_cylinder(
        puck_diam,
        puck_h,
        bottom_chamfer=0.35,
      )
    }
    body.as_shape().with_name(label).with_color(color)
  }

  // Left puck: base puck + N positive cross-slotted male snap-pins on top face.
  let male_parts : Array[@cad.SceneNode] = [
    make_puck_blank("male_puck_base", @cad.Rgb::orange()),
  ]
  for i in 0..<positions.length() {
    let (px, py) = positions[i]
    let pin = @fasteners.axial_snap_pin_male_node(
      params,
      name="snap_pin_male_\{i}",
      color=@cad.Rgb::orange(),
    ).translate(x=px, y=py, z=puck_h)
    male_parts.push(pin)
  }
  let male_puck = @cad.union_all(male_parts, name="snap_fit_male_puck")
    .with_color(@cad.Rgb::orange())
    .translate(x=-spacing)

  // Right puck: mating puck with N subtractive female 45-deg undercut sockets
  // entering from z = 0 (bed face) so it prints 100% support-free.
  let female_base = make_puck_blank("female_puck_base", @cad.Rgb::blue())
  let female_voids : Array[@cad.SceneNode] = []
  for i in 0..<positions.length() {
    let (px, py) = positions[i]
    let v = @fasteners.axial_snap_pin_female_void_node(
      params,
      name="snap_void_female_\{i}",
      color=@cad.Rgb::blue(),
    ).translate(x=px, y=py, z=0.0)
    female_voids.push(v)
  }
  let female_puck = @cad.difference(
      female_base,
      female_voids,
      name="snap_fit_female_puck",
    )
    .with_color(@cad.Rgb::blue())
    .translate(x=spacing)

  let design = @cad.Design::new(
      name="39-axial-snap-fit",
      description="Support-free 45-deg revolved axial snap-fit test pair",
    )
    .add(male_puck)
    .add(female_puck)

  let step_text = design.to_step_evaluated() catch {
    e => {
      @cli.eprintln("error: OCCT evaluation failed: " + e.to_string())
      abort("")
    }
  }
  @cad.write_text_file(step_text, Some(out_path))
  println("Wrote evaluated STEP: " + out_path)
}
