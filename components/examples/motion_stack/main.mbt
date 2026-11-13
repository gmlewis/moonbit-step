///|
/// components/examples/motion_stack
///
/// Generate a shaft / bearing / spacer stack:
///
/// ```bash
/// moon run components/examples/motion_stack -- \
///   --bearing 608 --shaftDiameter 8 --shaftLength 40 -o motion.step
/// moon run components/examples/motion_stack -- \
///   --part coupling --couplingBore 8 --couplingOuter 16 --couplingLength 20 -o coupling.step
/// moon run components/examples/motion_stack -- \
///   --part flange-housing --housingBearingOD 22 --housingBearingWidth 7 -o housing.step
/// moon run components/examples/motion_stack -- \
///   --part coupling --couplingBore 5 --couplingOuter 15 --couplingLength 20 \
///   --goldenFrame -o coupling-golden.step
/// ```
///
/// `--goldenFrame` is a comparison-only option: it maps the part into the
/// published golden reference frame (X-long, origin-centred) without changing
/// the builder's default Z-up, z = 0..length convention.
///
/// The bearings are simplified envelopes: rings plus cylindrical roller
/// proxies, not exact catalogue internals.
async fn main {
  let spec = {
    "bearing": @cli.opt_string(
      short='b',
      help="Bearing designation, e.g. 608, 6204",
    ),
    "shaftDiameter": @cli.opt_double(
      8.0,
      short='d',
      help="Shaft diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "shaftLength": @cli.opt_double(
      40.0,
      short='l',
      help="Shaft length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "spacerLength": @cli.opt_double(
      10.0,
      help="Spacer length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "detail": @cli.opt_string(
      short='D',
      help="Bearing detail: simplified (default), detailed, full",
    ),
    "part": @cli.opt_string(
      short='P',
      help="Part: stack (default), coupling, or flange-housing",
    ),
    "couplingBore": @cli.opt_double(
      8.0,
      help="Rigid coupling bore in mm",
      min=0.0,
    ),
    "couplingOuter": @cli.opt_double(
      16.0,
      help="Rigid coupling outside diameter in mm",
      min=0.0,
    ),
    "couplingLength": @cli.opt_double(
      20.0,
      help="Rigid coupling length in mm",
      min=0.0,
    ),
    "housingBearingOD": @cli.opt_double(
      22.0,
      help="Flanged housing bearing outside diameter in mm",
      min=0.0,
    ),
    "housingBearingWidth": @cli.opt_double(
      7.0,
      help="Flanged housing bearing width in mm",
      min=0.0,
    ),
    "housingFit": @cli.opt_double(
      0.0,
      help="Flanged housing seat fit allowance in mm (positive clearance, negative press)",
    ),
    "housingWall": @cli.opt_double(
      3.0,
      help="Flanged housing sleeve wall in mm",
      min=0.0,
    ),
    "housingFlange": @cli.opt_double(
      0.0,
      help="Flanged housing flange diameter in mm (0 = derived)",
      min=0.0,
    ),
    "housingBoltCircle": @cli.opt_double(
      0.0,
      help="Flanged housing bolt circle diameter in mm (0 = derived)",
      min=0.0,
    ),
    "housingBoltHole": @cli.opt_double(
      5.5,
      help="Flanged housing bolt hole diameter in mm",
      min=0.0,
    ),
    "housingBolts": @cli.opt_int(4, help="Flanged housing bolt-hole count"),
    "goldenFrame": @cli.flag(
      help="Emit the coupling in the published golden reference frame (X axis, centred; comparison only)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the assembly bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/motion_stack",
      description="Generate a shaft/bearing/spacer stack, a rigid coupling, or a flanged bearing housing.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("stack")
  if part_kind == "coupling" || part_kind == "flange-housing" {
    let mut component = if part_kind == "coupling" {
      match
        @motion.rigid_coupling(
          args.double("couplingBore"),
          args.double("couplingOuter"),
          args.double("couplingLength"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    } else {
      match
        @motion.flanged_bearing_housing(
          args.double("housingBearingOD"),
          args.double("housingBearingWidth"),
          wall_mm=args.double("housingWall"),
          fit_mm=args.double("housingFit"),
          flange_diameter_mm=args.double("housingFlange"),
          bolt_circle_diameter_mm=args.double("housingBoltCircle"),
          bolt_hole_diameter_mm=args.double("housingBoltHole"),
          bolt_count=args.int("housingBolts"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    if args.flag("goldenFrame") && part_kind == "coupling" {
      // The step.parts plain-sleeve reference is X-long and centred on the
      // origin. Keep the library's default Z-up, z = 0..length frame and map
      // only the golden-comparison output into the reference frame.
      component = component
        .rotate_y(90.0)
        .translate(x=-args.double("couplingLength") / 2.0)
    }
    if args.flag("bbox") {
      let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
      @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
    }
    component.write_step(args.string_opt("out"), checked=true)
    return
  }
  let bearing_name = args.string_opt("bearing").unwrap_or("608")
  let shaft_diameter = args.double("shaftDiameter")
  let shaft_length = args.double("shaftLength")
  let spacer_length = args.double("spacerLength")
  let shaft = match @motion.shaft(shaft_diameter, shaft_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_detail = parse_bearing_detail(
    args.string_opt("detail").unwrap_or("simplified"),
  )
  let bearing = match
    @motion.bearing_by_designation(bearing_name, detail=bearing_detail) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_size = match @motion.bearing_size(bearing_name) {
    Ok(s) => s
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if shaft_diameter > bearing_size.bore_mm + 1.0e-9 {
    @cli.eprintln(
      "error: shaft diameter must not exceed the bearing bore (\{bearing_size.bore_mm} mm)",
    )
    abort("")
  }
  let spacer_outer = shaft_diameter * 1.5
  let spacer = match
    @motion.spacer(spacer_outer, shaft_diameter, spacer_length) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let bearing_a_z = 5.0
  let bearing_b_z = shaft_length - bearing_size.width_mm - 5.0
  if bearing_b_z <= bearing_a_z + bearing_size.width_mm {
    @cli.eprintln("error: shaft is too short for two bearings")
    abort("")
  }
  let spacer_z = bearing_a_z + bearing_size.width_mm + 1.0
  if spacer_z + spacer_length > bearing_b_z {
    @cli.eprintln("error: spacer does not fit between the bearings")
    abort("")
  }
  let name = "motion-stack-\{bearing_name}"
  let assembly = @assemblies.Assembly::new(
      name~,
      description="Shaft with two simplified bearings and a spacer. Bearing rolling elements are cylindrical proxies.",
    )
    .add(shaft, instance_name="shaft")
    .add(
      bearing,
      placement=@common.Placement::translation(0.0, 0.0, bearing_a_z),
      instance_name="bearing-a",
    )
    .add(
      bearing,
      placement=@common.Placement::translation(0.0, 0.0, bearing_b_z),
      instance_name="bearing-b",
    )
    .add(
      spacer,
      placement=@common.Placement::translation(0.0, 0.0, spacer_z),
      instance_name="spacer",
    )
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = assembly.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  let out_path = args.string_opt("out")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(out_path)
    "flat" => assembly.write_step(out_path, checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}

///|
fn parse_bearing_detail(text : String) -> @common.DetailLevel {
  match text {
    "detailed" | "detail" => @common.DetailLevel::Detailed
    "full" | "fully-modeled" | "fully_modeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Simplified
  }
}
