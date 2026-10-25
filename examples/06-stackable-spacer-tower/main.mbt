///|
/// 06-stackable-spacer-tower
///
/// A set of stackable spacers with full-height tapers that let them stack
/// reliably despite print tolerances.
///
/// Usage (stdout):
///   moon run --target native examples/06-stackable-spacer-tower -- --count 3 > tower.step
async fn main {
  let base_args_spec = {
    "count": @cli.opt_double(
      1.0,
      help="Number of spacers in the tower",
      min=1.0,
    ),
    "id": @cli.opt_double(10.0, help="Inner diameter of the hole (mm)", min=1.0),
    "mid": @cli.opt_double(
      15.0,
      help="Diameter of the interlocking feature (mm)",
      min=2.0,
    ),
    "od": @cli.opt_double(
      25.0,
      help="Outer diameter of the spacer (mm)",
      min=3.0,
    ),
    "height": @cli.opt_double(
      5.0,
      help="Height of the spacer body (mm)",
      min=1.0,
    ),
    "clickHeight": @cli.opt_double(
      2.0,
      help="Height of the interlocking protrusion (mm)",
      min=0.5,
    ),
    "resolution": @cli.opt_double(64.0, help="Circle segments", min=3.0),
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
      prog="06-stackable-spacer-tower",
      description="Generate a stackable spacer tower.",
    )
    is Some(args) else {
    return
  }
  let count = args.double("count").to_int()
  let id = args.double("id")
  let mid = args.double("mid")
  let od = args.double("od")
  let height = args.double("height")
  let click_height = args.double("clickHeight")
  let resolution = args.double("resolution").to_int()
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

  // Basic validation
  if id >= mid {
    @cli.eprintln(
      "error: inner diameter (\{id}) must be less than middle diameter (\{mid})",
    )
    abort("")
  }
  if mid >= od {
    @cli.eprintln(
      "error: middle diameter (\{mid}) must be less than outer diameter (\{od})",
    )
    abort("")
  }
  if click_height >= height {
    @cli.eprintln(
      "error: clickHeight (\{click_height}) must be less than height (\{height})",
    )
    abort("")
  }
  let mut design = @cad.Design::new(
    name="spacer-tower",
    documentation=args.documentation(),
  )

  // Full-height draft: the female bore narrows over the whole body height and
  // the male outer surface narrows at the same cone angle over its full
  // height. This self-centres the parts and gives a constant clearance, so
  // print tolerances do not stop them stacking.
  let mut taper_d = 0.2
  if taper_d > (mid - id) * 0.3 {
    taper_d = (mid - id) * 0.3
  }
  if taper_d > (od - mid) * 0.3 {
    taper_d = (od - mid) * 0.3
  }
  let fit_clear = 0.05
  let colors = [@cad.Rgb::orange(), @cad.Rgb::green(), @cad.Rgb::blue()]
  for i in 0..<count {
    // Bodies stack directly on one another; each protrusion sits inside the
    // bore of the spacer above it.
    let base_z = tz + Double::from_int(i) * height
    let color = colors[i % 3]
    let spacer = stack_spacer(
      i, base_z, tx, ty, od, mid, id, height, click_height, taper_d, fit_clear, resolution,
      color,
    )
    design = design.add_iter(spacer.iter())
  }
  if blend_path is Some(blend_path) {
    design.create_blender_file(blend_path)
  } else if bpy_path is Some(_) {
    design.write_blender_python(bpy_path)
  } else {
    design.write_step(out_path)
  }
}

///|
/// stack_spacer builds one spacer: the female body ring whose bore is tapered
/// over the full body height, plus the male protrusion ring whose outer
/// surface is tapered over its full height at the same cone angle.
///
/// The cones are approximated by stacked rings because the CAD package has no
/// cone/revolve primitive. Eight layers on the body and four on the click give
/// diameter changes of only a few hundredths of a millimetre per layer.
fn stack_spacer(
  index : Int32,
  base_z : Double,
  tx : Double,
  ty : Double,
  od : Double,
  mid : Double,
  id : Double,
  height : Double,
  click_height : Double,
  taper_d : Double,
  fit_clear : Double,
  resolution : Int32,
  color : @cad.Rgb,
) -> Array[@cad.SceneNode] {
  let body_steps : Int32 = 8
  let click_steps : Int32 = 4
  let outer_circle = @cad.Profile2D::circle(od, segments=resolution)
  let inner_circle = @cad.Profile2D::circle(id, segments=resolution)
  let nodes : Array[@cad.SceneNode] = []

  // Female bore: largest at the bottom, narrowing to mid + fit_clear at the
  // top. Each layer uses its mid-height diameter to keep the stair-step small.
  let body_step_h = height / Double::from_int(body_steps)
  for k in 0..<body_steps {
    let z0 = Double::from_int(k) * body_step_h
    let zm = z0 + body_step_h / 2.0
    let bore = mid + fit_clear + taper_d * (1.0 - zm / height)
    nodes.push(
      @cad.ExtrudedProfile::new(outer_circle, body_step_h, holes=[
        @cad.Profile2D::circle(bore, segments=resolution),
      ])
      .with_name("spacer-body-\{index}-\{k}")
      .with_color(color)
      .translate(x=tx, y=ty, z=base_z + z0),
    )
  }

  // Male outer surface: mid at the bottom, narrowing at the same cone angle
  // (taper_d over the body height) across the click's full height.
  let click_base = base_z + height
  let click_step_h = click_height / Double::from_int(click_steps)
  for k in 0..<click_steps {
    let z0 = Double::from_int(k) * click_step_h
    let zm = z0 + click_step_h / 2.0
    let outer_d = mid - taper_d * zm / height
    nodes.push(
      @cad.ExtrudedProfile::new(
        @cad.Profile2D::circle(outer_d, segments=resolution),
        click_step_h,
        holes=[inner_circle],
      )
      .with_name("spacer-click-\{index}-\{k}")
      .with_color(color)
      .translate(x=tx, y=ty, z=click_base + z0),
    )
  }
  nodes
}
