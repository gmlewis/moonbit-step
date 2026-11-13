///|
/// components/examples/clamp_shaft_collar
///
/// Generate a one-piece clamp shaft collar whose radial slit, clamp-screw
/// clearance passage, and ISO 4762 head counterbore are real trimmed geometry,
/// with a plain-envelope ISO 4762 clamp screw placed in the counterbore. The
/// output is the OCCT-evaluated compound, because the kernel-free flat writer
/// cannot trim the slit or the holes.
///
/// ```bash
/// moon run components/examples/clamp_shaft_collar -- \
///   --bore 20 --outer 40 --width 15 --thread M6 \
///   --screwOffset 14.73 --screw M6 --screwLength 16 -o clamp-collar.step
/// ```
///
/// `--drill 0` and `--counterbore 0` use the collar defaults (nominal + 0.1 mm
/// clearance and the ISO 4762 head diameter + 0.2 mm). `--screwOffset 0` uses
/// the wall midline. The clamp thread is declared by connectors, never
/// modelled. `--noScrew` exports the collar alone.

///|
/// Axial inset of the plain-envelope head from the modelled head seat, enough
/// to keep the screw envelope disjoint from the collar so the evaluated output
/// is a two-solid compound (as in the reference). The clamp thread is a
/// declaration, not a contact.
const CLAMP_SCREW_SEAT_INSET_MM : Double = 0.05

///|
/// The reference renders the collar and its clamp screw in contrasting
/// materials. Keep that split so the screw stays visually distinct in the
/// evaluated compound.
const CLAMP_COLLAR_COLOR_R : Double = 0.56

///|
const CLAMP_COLLAR_COLOR_G : Double = 0.60

///|
const CLAMP_COLLAR_COLOR_B : Double = 0.64

///|
const CLAMP_SCREW_COLOR_R : Double = 0.07

///|
const CLAMP_SCREW_COLOR_G : Double = 0.085

///|
const CLAMP_SCREW_COLOR_B : Double = 0.10

///|
async fn main {
  let spec = {
    "bore": @cli.opt_double(
      20.0,
      help="Shaft bore diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "outer": @cli.opt_double(
      40.0,
      help="Outside diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      15.0,
      help="Collar width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thread": @cli.opt_string(
      help="ISO metric clamp-screw thread designation (default M6)",
    ),
    "drill": @cli.opt_double(
      0.0,
      help="Clamp clearance hole diameter in mm; 0 uses the collar default",
      min=0.0,
    ),
    "counterbore": @cli.opt_double(
      0.0,
      help="Head counterbore diameter in mm; 0 uses the collar default",
      min=0.0,
    ),
    "screwOffset": @cli.opt_double(
      0.0,
      help="Clamp-screw axis offset from the shaft axis in mm; 0 uses the wall midline",
      min=0.0,
    ),
    "slit": @cli.opt_double(0.8, help="Radial slit width in mm", min=0.0),
    "chamfer": @cli.opt_double(0.2, help="45 degree rim chamfer in mm", min=0.0),
    "screw": @cli.opt_string(
      help="ISO 4762 clamp screw size to place (default M6)",
    ),
    "screwLength": @cli.opt_double(
      16.0,
      help="ISO 4762 clamp screw length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "noScrew": @cli.flag(help="Omit the clamp screw and export the collar only"),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/clamp_shaft_collar",
      description="Generate a clamp shaft collar with a real slit and clamp screw.",
    )
    is Some(args) else {
    return
  }
  let bore = args.double("bore")
  let outer = args.double("outer")
  let width = args.double("width")
  let thread_text = match args.string_opt("thread") {
    Some(text) => text
    None => "M6"
  }
  let thread = match @standards.MetricSize::parse(thread_text) {
    Some(size) => size
    None => {
      @cli.eprintln(
        "error: unknown ISO metric thread designation: " + thread_text,
      )
      abort("")
    }
  }
  let drill_arg = args.double("drill")
  let counterbore_arg = args.double("counterbore")
  let offset_arg = args.double("screwOffset")
  let collar = match
    @motion.clamp_shaft_collar(
      bore,
      outer,
      width,
      thread~,
      drill_diameter_mm?=if drill_arg > 0.0 { Some(drill_arg) } else { None },
      counterbore_diameter_mm?=if counterbore_arg > 0.0 {
        Some(counterbore_arg)
      } else {
        None
      },
      screw_offset_mm?=if offset_arg > 0.0 { Some(offset_arg) } else { None },
      slit_width_mm=args.double("slit"),
      chamfer_mm=args.double("chamfer"),
      color=@cad.Rgb::new(
        CLAMP_COLLAR_COLOR_R,
        CLAMP_COLLAR_COLOR_G,
        CLAMP_COLLAR_COLOR_B,
      ),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let mut component = collar
  if !args.flag("noScrew") {
    let screw_text = match args.string_opt("screw") {
      Some(text) => text
      None => "M6"
    }
    let screw_size = match @standards.MetricSize::parse(screw_text) {
      Some(size) => size
      None => {
        @cli.eprintln(
          "error: unknown ISO 4762 clamp-screw designation: " + screw_text,
        )
        abort("")
      }
    }
    let head = match @standards.iso4762_size(screw_size) {
      Ok(size) => size
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    let drill = match collar.connector("clamp-screw-hole") {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    let seat = match collar.connector("head-seat") {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    let drill_diameter = drill.diameter_mm.unwrap()
    let seat_diameter = seat.diameter_mm.unwrap()
    if head.thread.nominal_diameter_mm >= drill_diameter {
      @cli.eprintln(
        "error: clamp screw \{screw_size.designation()} (\{head.thread.nominal_diameter_mm} mm) does not fit the modelled \{drill_diameter} mm hole",
      )
      abort("")
    }
    if head.head_diameter_mm >= seat_diameter {
      @cli.eprintln(
        "error: clamp screw \{screw_size.designation()} head (\{head.head_diameter_mm} mm) does not fit the modelled \{seat_diameter} mm counterbore",
      )
      abort("")
    }
    let screw_length = args.double("screwLength")
    // The reference models a threaded shank whose root sits well inside the
    // clamp clearance hole. Model the plain envelope at the ISO 68-1 external
    // thread minor diameter so the screw reads as a shaft in the hole instead
    // of a smooth plug flush with it.
    let shank_diameter = @standards.ThreadSpec::coarse(screw_size).external_minor_diameter_mm()
    let screw = match
      @fasteners.iso4762_screw(
        screw_size,
        screw_length,
        shank_diameter_mm=shank_diameter,
      ) {
      Ok(c) => c
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
    // ISO 4762: head underside at z = 0, head +Z, shank -Z. Rotate +Z to +X so
    // the head enters the +X counterbore, then seat it on the modelled head
    // seat.
    let (seat_x, seat_y, seat_z) = seat.placement.trans
    let placed = screw
      .rotate_y(90.0)
      .translate(x=seat_x + CLAMP_SCREW_SEAT_INSET_MM, y=seat_y, z=seat_z)
    let mut index = 0
    for layer in placed.layers() {
      component = component.add_layer(
        layer.shape,
        name="clamp-screw-\{index}",
        color=@cad.Rgb::new(
          CLAMP_SCREW_COLOR_R,
          CLAMP_SCREW_COLOR_G,
          CLAMP_SCREW_COLOR_B,
        ),
        placement=layer.placement,
      )
      index = index + 1
    }
    for connector in placed.connectors() {
      component = component.with_connector_unchecked(connector)
    }
    let features = @common.FeatureRecord::new(
      modeled=[
        "collar", "outside-cylinder", "bore", "rim-chamfers", "clamp-slit", "clamp-screw-hole",
        "head-counterbore", "clamp-screw-envelope",
      ],
      approximated=[],
      omitted=[
        @common.Omission::new(
          feature="clamp-screw-thread",
          reason="the clamp thread interface is declared by the clamp-screw-thread and thread-start connectors, not modelled",
        ),
        @common.Omission::new(
          feature="holding-torque-and-material",
          reason="nominal geometry only; no holding torque, material, or strength claim",
        ),
      ],
    )
    let metadata = @common.Metadata::new(
      designation="Clamp shaft collar \{@cad.fmt_double(bore, None)} bore x \{@cad.fmt_double(outer, None)} OD x \{@cad.fmt_double(width, None)} with ISO 4762 \{screw_size.designation()} x \{@cad.fmt_double(screw_length, None)} clamp screw",
      standard="ISO 4762 (clamp screw envelope); ISO 261 / ISO 68-1 (thread interface)",
      family="clamp shaft collar assembly",
      size="\{@cad.fmt_double(bore, None)}x\{@cad.fmt_double(outer, None)}x\{@cad.fmt_double(width, None)}-\{screw_size.designation()}x\{@cad.fmt_double(screw_length, None)}",
      length_mm=screw_length,
      source="Parametric clamp collar with a trimmed slit and clamp-screw holes plus an ISO 4762 plain-envelope clamp screw; the thread is declared, not modelled.",
    )
    component = component
      .with_metadata(metadata)
      .with_description(
        "One-piece clamp shaft collar with an ISO 4762 plain-envelope clamp screw on the head seat. The slit, clearance passage, and counterbore are OCCT-trimmed; the clamp thread is declared by connectors and not modelled.",
      )
      .with_features(features)
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step_evaluated(args.string_opt("out"))
}
