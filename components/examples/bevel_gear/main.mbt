///|
/// components/examples/bevel_gear
///
/// Build an external straight bevel gear with the Tredgold back-cone tooth
/// sector. The default large end uses the standard back-cone tooth ends with a
/// flat root-circle backing plane; `--endFace flat` selects the older flat-back
/// variant, whose outside diameter is larger than the standard value. The root
/// fillet is available only with `--endFace flat`.
///
/// ```bash
/// moon run components/examples/bevel_gear -- \
///   --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --bore 6 \
///   -o bevel.step
/// moon run components/examples/bevel_gear -- \
///   --module 2 --teeth 16 --pitchAngle 30 --faceWidth 8 -o bevel-standalone.step
/// moon run components/examples/bevel_gear -- \
///   --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --backlash 0.05 \
///   --pair -o bevel-pair.step
/// moon run components/examples/bevel_gear -- \
///   --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --rootFillet 0.2 \
///   --tipChamfer 0.1 --endFace flat -o bevel-filleted.step
/// moon run components/examples/bevel_gear -- \
///   --module 2 --teeth 20 --mateTeeth 40 --faceWidth 10 --bore 6 \
///   --hubDiameter 14 --hubLength 8 -o bevel-hub.step
/// ```
///
/// This is a static geometry envelope. The tooth form is the standard Tredgold
/// approximation of the octoid/spherical involute, not an exact conjugate
/// tooth; no contact, load, or strength rating is implied.
async fn main {
  let spec = {
    "module": @cli.opt_double(
      2.0,
      help="Gear module in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "teeth": @cli.opt_int(20, help="Gear tooth count"),
    "mateTeeth": @cli.opt_int(
      40,
      help="Mate tooth count (ignored when --pitchAngle is given)",
    ),
    "shaftAngle": @cli.opt_double(90.0, help="Shaft angle in degrees"),
    "pitchAngle": @cli.opt_double(
      0.0,
      help="Explicit pitch cone angle in degrees (0 = derive from mateTeeth)",
      min=0.0,
    ),
    "pressureAngle": @cli.opt_double(20.0, help="Pressure angle in degrees"),
    "faceWidth": @cli.opt_double(
      10.0,
      help="Face width measured along the pitch cone, in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "bore": @cli.opt_double(
      0.0,
      help="Central bore diameter in mm (0 = no bore)",
      min=0.0,
    ),
    "backlash": @cli.opt_double(
      0.0,
      help="Per-gear tooth thickness reduction at the reference circle",
      min=0.0,
    ),
    "involutePoints": @cli.opt_int(12, help="Points per involute flank"),
    "arcPoints": @cli.opt_int(8, help="Points per tip/root arc"),
    "rootFillet": @cli.opt_double(
      0.0,
      help="Back-cone root fillet radius in mm (0 = sharp root)",
      min=0.0,
    ),
    "filletSegments": @cli.opt_int(4, help="Segments per root fillet arc"),
    "tipChamfer": @cli.opt_double(
      0.0,
      help="Tip chamfer distance in mm (0 = sharp tip)",
      min=0.0,
    ),
    "hubDiameter": @cli.opt_double(
      0.0,
      help="Hub outside diameter behind the back face in mm (0 = no hub)",
      min=0.0,
    ),
    "hubLength": @cli.opt_double(
      0.0,
      help="Hub length behind the back face in mm (0 = no hub)",
      min=0.0,
    ),
    "keywayWidth": @cli.opt_double(
      0.0,
      help="Bore keyway width in mm (0 = no keyway; requires --bore)",
      min=0.0,
    ),
    "keywayDepth": @cli.opt_double(
      0.0,
      help="Bore keyway radial depth in mm (0 = no keyway)",
      min=0.0,
    ),
    "keywayAngle": @cli.opt_double(
      90.0,
      help="Keyway angular position in the XY plane, degrees",
    ),
    "setScrew": @cli.opt_double(
      0.0,
      help="Radial set-screw hole diameter in mm (0 = no hole)",
      min=0.0,
    ),
    "setScrewAngle": @cli.opt_double(
      180.0,
      help="Set-screw hole angular position in the XY plane, degrees",
    ),
    "setScrewOffset": @cli.opt_double(
      -1.0,
      help="Set-screw hole axial position from the hub back face in mm (-1 = mid-hub)",
    ),
    "edgeChamfer": @cli.opt_double(
      0.0,
      help="45-degree edge break on the tooth ends, bore, and hub in mm (0 = sharp)",
      min=0.0,
    ),
    "endChamfer": @cli.opt_double(
      0.0,
      help="Explicit 45-degree chamfer band around the front tooth outline in mm (0 = sharp)",
      min=0.0,
    ),
    "tipLand": @cli.opt_double(
      0.0,
      help="Physical outside radius of the tooth tip land in mm (0 = theoretical back-cone tip)",
      min=0.0,
    ),
    "endFace": @cli.opt_string(
      short='e',
      help="Large end: backCone (default) or flat",
    ),
    "pair": @cli.flag(
      help="Write the driver and a mate tooth count as a meshing bevel pair",
    ),
    "mateBore": @cli.opt_double(
      0.0,
      help="Driven gear bore diameter in mm (pair mode; 0 = no bore)",
      min=0.0,
    ),
    "mateFaceWidth": @cli.opt_double(
      0.0,
      help="Driven gear face width in mm (0 = same as the driver)",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
    "evaluated": @cli.flag(
      help="Fuse the layers and evaluate the final solid with OCCT",
    ),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/bevel_gear",
      description="Generate an external straight bevel gear.",
    )
    is Some(args) else {
    return
  }
  let pitch_angle = args.double("pitchAngle")
  let mate_teeth = if pitch_angle > 0.0 { 0 } else { args.int("mateTeeth") }
  let end_face = match args.string_opt("endFace").unwrap_or("backCone") {
    "flat" => @gears.BevelEndFace::Flat
    "backCone" => @gears.BevelEndFace::BackCone
    other => {
      @cli.eprintln("error: unsupported end face: " + other)
      abort("")
    }
  }
  let params = match
    @gears.BevelGearParams::new(
      module_mm=args.double("module"),
      teeth=args.int("teeth"),
      mate_teeth~,
      shaft_angle_deg=args.double("shaftAngle"),
      pitch_angle_deg?=if pitch_angle > 0.0 {
        Some(pitch_angle)
      } else {
        (None : Double?)
      },
      pressure_angle_deg=args.double("pressureAngle"),
      face_width_mm=args.double("faceWidth"),
      bore_diameter_mm=args.double("bore"),
      backlash_mm=args.double("backlash"),
      involute_points=args.int("involutePoints"),
      arc_points=args.int("arcPoints"),
      root_fillet_radius_mm=args.double("rootFillet"),
      fillet_segments=args.int("filletSegments"),
      tip_chamfer_mm=args.double("tipChamfer"),
      hub_diameter_mm=args.double("hubDiameter"),
      hub_length_mm=args.double("hubLength"),
      keyway_width_mm=args.double("keywayWidth"),
      keyway_depth_mm=args.double("keywayDepth"),
      keyway_angle_deg=args.double("keywayAngle"),
      set_screw_diameter_mm=args.double("setScrew"),
      set_screw_angle_deg=args.double("setScrewAngle"),
      set_screw_offset_mm?=if args.double("setScrewOffset") >= 0.0 {
        Some(args.double("setScrewOffset"))
      } else {
        (None : Double?)
      },
      edge_chamfer_mm=args.double("edgeChamfer"),
      end_chamfer_mm=args.double("endChamfer"),
      tip_land_radius_mm=args.double("tipLand"),
      end_face~,
    ) {
    Ok(p) => p
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if (
      args.double("keywayWidth") > 0.0 ||
      args.double("setScrew") > 0.0 ||
      args.double("edgeChamfer") > 0.0
    ) &&
    !args.flag("evaluated") {
    @cli.eprintln(
      "error: a keyway, set-screw hole, or edge chamfer requires --evaluated",
    )
    abort("")
  }
  if args.flag("pair") {
    if args.flag("evaluated") {
      @cli.eprintln("error: --evaluated applies to a single gear, not a pair")
      abort("")
    }
    if pitch_angle > 0.0 || mate_teeth < 1 {
      @cli.eprintln("error: pair mode needs --mateTeeth and no --pitchAngle")
      abort("")
    }
    let mate_face = args.double("mateFaceWidth")
    let driven = match
      @gears.BevelGearParams::new(
        module_mm=args.double("module"),
        teeth=args.int("mateTeeth"),
        mate_teeth=args.int("teeth"),
        shaft_angle_deg=args.double("shaftAngle"),
        pressure_angle_deg=args.double("pressureAngle"),
        face_width_mm=if mate_face > 0.0 {
          mate_face
        } else {
          args.double("faceWidth")
        },
        bore_diameter_mm=args.double("mateBore"),
        backlash_mm=args.double("backlash"),
        involute_points=args.int("involutePoints"),
        arc_points=args.int("arcPoints"),
        root_fillet_radius_mm=args.double("rootFillet"),
        fillet_segments=args.int("filletSegments"),
        tip_chamfer_mm=args.double("tipChamfer"),
        hub_diameter_mm=args.double("hubDiameter"),
        hub_length_mm=args.double("hubLength"),
        end_face~,
      ) {
      Ok(p) => p
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    let pair = match @gears.bevel_gear_pair(params, driven) {
      Ok(a) => a
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    if args.flag("bbox") {
      let (x0, x1, y0, y1, z0, z1) = pair.bounding_box()
      @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
    }
    pair.write_step(args.string_opt("out"), checked=true)
    return
  }
  let gear = match @gears.bevel_gear(params) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = gear.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if args.flag("evaluated") {
    gear.write_step_evaluated(args.string_opt("out"))
  } else {
    gear.write_step(args.string_opt("out"), checked=true)
  }
}
