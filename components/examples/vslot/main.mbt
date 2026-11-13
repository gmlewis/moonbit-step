///|
/// components/examples/vslot
///
/// Generate OpenBuilds V-Slot system parts:
///
/// ```bash
/// moon run components/examples/vslot -- --part profile --profile 2020 --length 100 -o vslot.step
/// moon run components/examples/vslot -- --part wheel -o vwheel.step
/// moon run components/examples/vslot -- --part tnut -o tnut.step
/// moon run components/examples/vslot -- --part plate --length 60 --width 20 --thickness 3 -o plate.step
/// ```
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='p',
      help="Part: profile (default), wheel, tnut, plate",
    ),
    "profile": @cli.opt_string(help="V-Slot section: 2020 (default) or 2040"),
    "length": @cli.opt_double(100.0, help="Extrusion length in mm", min=0.0),
    "width": @cli.opt_double(20.0, help="Plate width in mm", min=0.0),
    "thickness": @cli.opt_double(3.0, help="Plate thickness in mm", min=0.0),
    "slotPitch": @cli.opt_double(
      20.0,
      help="Joining-plate slot pitch in mm",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/vslot",
      description="Generate OpenBuilds V-Slot profiles, wheels, T-nuts, and joining plates.",
    )
    is Some(args) else {
    return
  }
  let part_kind = args.string_opt("part").unwrap_or("profile")
  let component = match part_kind {
    "wheel" =>
      match @motion.v_wheel(@motion.VWheelSpec::openbuilds_solid_v()) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "tnut" =>
      match @fasteners.vslot_t_nut(@fasteners.SlotTNutSpec::openbuilds_m5()) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    "plate" => {
      let length = args.double("length")
      let width = args.double("width")
      let pitch = args.double("slotPitch")
      match
        @stock.vslot_joining_plate(
          length,
          width,
          args.double("thickness"),
          pitch,
          10.0,
          5.5,
        ) {
        Ok(c) => c
        Err(e) => {
          @cli.eprintln("error: " + e.message())
          abort("")
        }
      }
    }
    _ => {
      let profile_name = args.string_opt("profile").unwrap_or("2020")
      let profile = match profile_name {
        "2040" => @profiles.VSlotProfile::vslot_2040()
        "2020" => @profiles.VSlotProfile::vslot_2020()
        other => {
          @cli.eprintln("error: unsupported V-Slot section: " + other)
          abort("")
        }
      }
      match @profiles.vslot_extrusion(profile, args.double("length")) {
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
  component.write_step(args.string_opt("out"), checked=true)
}
