///|
/// components/examples/stock_primitive
///
/// Generate a steel angle section or a flat plate blank:
///
/// ```bash
/// moon run components/examples/stock_primitive -- \
///   --part angle --legA 40 --legB 40 --thickness 4 --length 50 -o angle.step
/// moon run components/examples/stock_primitive -- \
///   --part plate --width 50 --height 50 --plateThickness 3 -o plate.step
/// moon run components/examples/stock_primitive -- \
///   --part counterbore --width 50 --height 40 --plateThickness 8 \
///   --holeSpacing 24 --through 5.5 --counterbore 9 --counterboreDepth 2 -o cb.step
/// moon run components/examples/stock_primitive -- \
///   --part bearing --width 50 --height 40 --plateThickness 6 \
///   --bearingOD 22 --fit 0.1 --boltDiameter 5.5 --holeSpacing 30 -o bearing.step
/// moon run components/examples/stock_primitive -- \
///   --part countersink --width 50 --height 40 --plateThickness 8 \
///   --holeSpacing 24 --through 5.5 --countersinkDiameter 9 --countersinkDepth 2 -o cs.step
/// moon run components/examples/stock_primitive -- \
///   --part tube-bracket --tubeOD 17.9324 --tubeClearance 0.5 --width 60 --height 40 -o bracket.step
/// moon run components/examples/stock_primitive -- --part sc8uu -o sc8uu.step
/// moon run components/examples/stock_primitive -- --part heat-boss -o heat-boss.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: angle (default), plate, counterbore, countersink, tube-bracket, bearing, sc8uu, or heat-boss",
    ),
    "legA": @cli.opt_double(40.0, help="Angle leg A in mm", min=0.0),
    "legB": @cli.opt_double(40.0, help="Angle leg B in mm", min=0.0),
    "thickness": @cli.opt_double(4.0, help="Angle leg thickness in mm", min=0.0),
    "rootRadius": @cli.opt_double(
      6.0,
      help="Angle root fillet radius in mm",
      min=0.0,
    ),
    "toeRadius": @cli.opt_double(3.0, help="Angle toe radius in mm", min=0.0),
    "length": @cli.opt_double(50.0, help="Angle bar length in mm", min=0.0),
    "width": @cli.opt_double(50.0, help="Plate width in mm", min=0.0),
    "height": @cli.opt_double(50.0, help="Plate height in mm", min=0.0),
    "plateThickness": @cli.opt_double(
      3.0,
      help="Plate thickness in mm",
      min=0.0,
    ),
    "holeSpacing": @cli.opt_double(
      20.0,
      help="Counterbored-plate hole spacing in mm",
      min=0.0,
    ),
    "through": @cli.opt_double(
      5.5,
      help="Counterbored-plate through-hole diameter in mm",
      min=0.0,
    ),
    "counterbore": @cli.opt_double(
      9.0,
      help="Counterbored-plate counterbore diameter in mm",
      min=0.0,
    ),
    "counterboreDepth": @cli.opt_double(
      2.0,
      help="Counterbored-plate counterbore depth in mm",
      min=0.0,
    ),
    "countersinkDiameter": @cli.opt_double(
      9.0,
      help="Countersunk-plate seat diameter in mm",
      min=0.0,
    ),
    "countersinkDepth": @cli.opt_double(
      2.0,
      help="Countersunk-plate seat depth in mm",
      min=0.0,
    ),
    "tubeOD": @cli.opt_double(
      17.9324,
      help="Tube-to-V-Slot bracket tube outside diameter in mm",
      min=0.0,
    ),
    "tubeClearance": @cli.opt_double(
      0.5,
      help="Tube-to-V-Slot bracket bore clearance in mm",
      min=0.0,
    ),
    "slotPitch": @cli.opt_double(
      40.0,
      help="Tube-to-V-Slot bracket slot pitch in mm",
      min=0.0,
    ),
    "slotLength": @cli.opt_double(
      10.0,
      help="Tube-to-V-Slot bracket slot length in mm",
      min=0.0,
    ),
    "slotWidth": @cli.opt_double(
      5.5,
      help="Tube-to-V-Slot bracket slot width in mm",
      min=0.0,
    ),
    "bearingOD": @cli.opt_double(
      22.0,
      help="Bearing outside diameter for the bearing plate in mm",
      min=0.0,
    ),
    "fit": @cli.opt_double(
      0.1,
      help="Bearing seat radial fit in mm (positive clearance, negative press)",
    ),
    "boltDiameter": @cli.opt_double(
      5.5,
      help="Bearing plate bolt-hole diameter in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/stock_primitive",
      description="Generate an angle section or a plate blank.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("angle")
  let component = match part_kind {
    "sc8uu" =>
      match @stock.sc8uu_bearing_block() {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "heat-boss" =>
      match @stock.heat_set_boss_m3x4() {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "countersink" => {
      let spacing = args.double("holeSpacing")
      let holes : Array[@stock.CountersunkHole] = [
        @stock.CountersunkHole::{
          x_mm: -spacing / 2.0,
          y_mm: 0.0,
          through_diameter_mm: args.double("through"),
          countersink_diameter_mm: args.double("countersinkDiameter"),
          countersink_depth_mm: args.double("countersinkDepth"),
        },
        @stock.CountersunkHole::{
          x_mm: spacing / 2.0,
          y_mm: 0.0,
          through_diameter_mm: args.double("through"),
          countersink_diameter_mm: args.double("countersinkDiameter"),
          countersink_depth_mm: args.double("countersinkDepth"),
        },
      ]
      match
        @stock.plate_with_countersinks(
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
          holes~,
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    "tube-bracket" =>
      match
        @stock.tube_to_vslot_bracket(
          args.double("tubeOD"),
          args.double("tubeClearance"),
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
          args.double("slotPitch"),
          args.double("slotLength"),
          args.double("slotWidth"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "bearing" =>
      match
        @stock.bearing_plate(
          args.double("bearingOD"),
          args.double("fit"),
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
          args.double("boltDiameter"),
          args.double("holeSpacing"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "counterbore" => {
      let spacing = args.double("holeSpacing")
      let holes : Array[@stock.CounterboredHole] = [
        @stock.CounterboredHole::{
          x_mm: -spacing / 2.0,
          y_mm: 0.0,
          through_diameter_mm: args.double("through"),
          counterbore_diameter_mm: args.double("counterbore"),
          counterbore_depth_mm: args.double("counterboreDepth"),
        },
        @stock.CounterboredHole::{
          x_mm: spacing / 2.0,
          y_mm: 0.0,
          through_diameter_mm: args.double("through"),
          counterbore_diameter_mm: args.double("counterbore"),
          counterbore_depth_mm: args.double("counterboreDepth"),
        },
      ]
      match
        @stock.plate_with_counterbores(
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
          holes~,
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    "plate" =>
      match
        @stock.plate(
          args.double("width"),
          args.double("height"),
          args.double("plateThickness"),
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    _ => {
      let section = match
        @stock.angle_section(
          leg_a_mm=args.double("legA"),
          leg_b_mm=args.double("legB"),
          thickness_mm=args.double("thickness"),
          root_radius_mm=args.double("rootRadius"),
          toe_radius_mm=args.double("toeRadius"),
        ) {
        Ok(s) => s
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
      match @stock.angle_bar(section, args.double("length")) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  if part_kind == "sc8uu" {
    component.write_step_evaluated(args.string_opt("out"))
  } else {
    component.write_step(args.string_opt("out"), checked=true)
  }
}
