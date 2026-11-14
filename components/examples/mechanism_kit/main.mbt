///|
/// components/examples/mechanisms
///
/// Generate one generic mechanism or structural primitive:
///
/// ```bash
/// moon run components/examples/mechanisms -- --part hinge -o hinge.step
/// moon run components/examples/mechanisms -- --part linkage --length 120 -o link.step
/// moon run components/examples/mechanisms -- --part belt -o belt.step
/// moon run components/examples/mechanisms -- --part oldham -o oldham.step
/// moon run components/examples/mechanisms -- --part rack -o rack.step
/// ```
///
/// All dimensions are millimetres and Z is up unless a part documents another
/// axis. Every part is an engineering envelope; no load, torque, or safety
/// rating is implied.
async fn main {
  let spec = {
    "part": @cli.opt_string(
      short='P',
      help="Part: hinge, clevis, pin, rod-end, linkage, rail, carriage, lead-screw, lead-nut, belt, belt-unequal, cam, roller, oldham, extension-spring, torsion-spring, snap, o-ring, grooved-shaft, bracket, u-bracket, z-bracket, boss, rack, sprocket, chain-segment",
    ),
    "length": @cli.opt_double(
      100.0,
      short='l',
      help="Primary length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "width": @cli.opt_double(
      20.0,
      short='w',
      help="Primary width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "height": @cli.opt_double(
      15.0,
      help="Primary height in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "thickness": @cli.opt_double(
      6.0,
      short='t',
      help="Primary thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "diameter": @cli.opt_double(
      8.0,
      short='d',
      help="Primary diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pinDiameter": @cli.opt_double(
      4.0,
      help="Hinge pin diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "camRadius": @cli.opt_double(
      20.0,
      help="Cam base radius in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "legA": @cli.opt_double(
      100.0,
      help="Bracket base leg in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "legB": @cli.opt_double(
      50.0,
      help="Bracket upright leg in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "baseThickness": @cli.opt_double(
      6.0,
      help="Rack base thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "railBase": @cli.opt_double(
      0.0,
      help="Rail base slab thickness in mm (0 = derived)",
      min=0.0,
    ),
    "bore": @cli.opt_double(5.0, help="Primary bore in mm", min=0.0),
    "grooveWidth": @cli.opt_double(4.0, help="Groove width in mm", min=0.0),
    "grooveDepth": @cli.opt_double(2.0, help="Groove depth in mm", min=0.0),
    "grooveCenter": @cli.opt_double(25.0, help="Groove centre in mm", min=0.0),
    "knuckles": @cli.opt_int(3, help="Hinge knuckle count"),
    "leafAngle": @cli.opt_double(
      0.0,
      help="Hinge leaf B opening angle in degrees",
    ),
    "gap": @cli.opt_double(8.0, help="Clevis gap in mm", min=0.0),
    "clearance": @cli.opt_double(0.03, help="Sliding clearance in mm", min=0.0),
    "slotLength": @cli.opt_double(
      0.0,
      help="Adjustment slot length in mm",
      min=0.0,
    ),
    "slotWidth": @cli.opt_double(
      0.0,
      help="Adjustment slot width in mm",
      min=0.0,
    ),
    "eccentricity": @cli.opt_double(5.0, help="Cam eccentricity in mm", min=0.0),
    "wire": @cli.opt_double(
      2.0,
      help="Spring wire diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "coils": @cli.opt_int(8, help="Spring active coils"),
    "segments": @cli.opt_int(16, help="Spring segments per coil"),
    "legLength": @cli.opt_double(10.0, help="Spring leg length in mm", min=0.0),
    "hookLoop": @cli.opt_double(
      0.0,
      help="Extension-spring end-loop radius in mm (0 = straight legs)",
      min=0.0,
    ),
    "hookDepth": @cli.opt_double(
      3.0,
      help="Snap hook engagement depth in mm",
      min=0.0,
    ),
    "rampLength": @cli.opt_double(5.0, help="Snap ramp length in mm", min=0.0),
    "gusset": @cli.opt_double(
      0.0,
      help="Bracket corner gusset size in mm",
      min=0.0,
    ),
    "eyeOuter": @cli.opt_double(
      20.0,
      help="Rod-end eye outer diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "eyeWidth": @cli.opt_double(
      8.0,
      help="Rod-end eye width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "pulleyB": @cli.opt_double(
      40.0,
      help="Second pulley pitch diameter in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "module": @cli.opt_double(
      2.0,
      help="Rack module in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "teeth": @cli.opt_int(10, help="Rack tooth count"),
    "sprocketTeeth": @cli.opt_int(16, help="ANSI #40 sprocket tooth count"),
    "chainPitches": @cli.opt_int(10, help="ANSI #40 chain-segment pitch count"),
    "threadDiameter": @cli.opt_double(
      6.0,
      help="Tapped thread nominal diameter in mm",
      min=0.0,
    ),
    "threadPitch": @cli.opt_double(
      1.0,
      help="Tapped thread pitch in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "threadDepth": @cli.opt_double(
      10.0,
      help="Tapped thread depth in mm",
      min=0.0,
    ),
    "counterbore": @cli.opt_double(
      0.0,
      help="Boss counterbore diameter in mm",
      min=0.0,
    ),
    "counterboreDepth": @cli.opt_double(
      0.0,
      help="Boss counterbore depth in mm",
      min=0.0,
    ),
    "evaluated": @cli.flag(
      help="Fuse layers and export an OCCT-evaluated STEP (requires OCCT)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/mechanisms",
      description="Generate one generic mechanism or structural primitive.",
    )
    is Some(args) else {
    return
  }
  let part = args.string_opt("part").unwrap_or("hinge")
  let length = args.double("length")
  let width = args.double("width")
  let height = args.double("height")
  let thickness = args.double("thickness")
  let diameter = args.double("diameter")
  let bore = args.double("bore")
  let result : Result[@common.Component, @common.SpecError] = match part {
    "hinge" =>
      @mechanisms.hinge(
        length,
        width,
        thickness,
        args.double("pinDiameter"),
        knuckles=args.int("knuckles"),
        leaf_angle_deg=args.double("leafAngle"),
      )
    "clevis" =>
      @mechanisms.clevis(
        width,
        height,
        thickness,
        thickness,
        args.double("gap"),
        diameter,
      )
    "pin" =>
      @mechanisms.clevis_pin(diameter, length, diameter * 1.6, length * 0.1)
    "rod-end" =>
      @mechanisms.rod_end(
        args.double("eyeOuter"),
        bore,
        args.double("eyeWidth"),
        diameter,
        length,
      )
    "linkage" =>
      @mechanisms.linkage_bar(
        length,
        width,
        thickness,
        diameter,
        slot_length_mm=args.double("slotLength"),
        slot_width_mm=args.double("slotWidth"),
      )
    "rail" =>
      match
        @mechanisms.linear_rail_profile(
          width_mm=width,
          height_mm=height,
          groove_width_mm=args.double("grooveWidth"),
          groove_depth_mm=args.double("grooveDepth"),
        ) {
        Ok(profile) => {
          let base = args.double("railBase")
          if base > 0.0 {
            @mechanisms.linear_rail(profile, length, base_thickness_mm=base)
          } else {
            @mechanisms.linear_rail(profile, length)
          }
        }
        Err(e) => Err(e)
      }
    "carriage" =>
      match
        @mechanisms.linear_rail_profile(
          width_mm=width,
          height_mm=height,
          groove_width_mm=args.double("grooveWidth"),
          groove_depth_mm=args.double("grooveDepth"),
        ) {
        Ok(profile) =>
          @mechanisms.linear_carriage(
            profile,
            length,
            width * 2.0,
            height * 2.0,
            clearance_mm=args.double("clearance"),
            bolt_hole_diameter_mm=args.double("bore"),
          )
        Err(e) => Err(e)
      }
    "lead-screw" =>
      @mechanisms.lead_screw(
        diameter,
        length,
        lead_mm=args.double("threadPitch"),
      )
    "lead-nut" =>
      @mechanisms.lead_screw_nut(
        width,
        length,
        width * 1.5,
        thickness,
        diameter,
        args.double("threadPitch"),
      )
    "belt" => @mechanisms.belt_loop(diameter, length, thickness, width)
    "belt-unequal" =>
      @mechanisms.belt_loop_unequal(
        diameter,
        args.double("pulleyB"),
        length,
        thickness,
        width,
      )
    "cam" =>
      @mechanisms.eccentric_cam(
        args.double("camRadius"),
        args.double("eccentricity"),
        thickness,
        bore,
      )
    "roller" =>
      @mechanisms.roller_follower(
        diameter,
        width,
        bore,
        bore * 0.8,
        width * 1.25,
      )
    "oldham" => {
      let requested = args.double("slotWidth")
      let tongue = if requested > 0.0 {
        requested
      } else {
        let candidate = width * 0.3
        if candidate < bore * 0.7 {
          candidate
        } else {
          bore * 0.7
        }
      }
      @mechanisms.oldham_coupling(
        bore,
        width,
        thickness,
        width * 0.9,
        thickness * 0.5,
        tongue,
      )
    }
    "extension-spring" =>
      @mechanisms.extension_spring(
        width,
        args.double("wire"),
        length,
        args.int("coils"),
        leg_length_mm=args.double("legLength"),
        hook_loop_radius_mm=args.double("hookLoop"),
        segments_per_turn=args.int("segments"),
      )
    "torsion-spring" =>
      @mechanisms.torsion_spring(
        width,
        args.double("wire"),
        length,
        args.int("coils"),
        leg_length_mm=args.double("legLength"),
        segments_per_turn=args.int("segments"),
      )
    "snap" =>
      @mechanisms.snap_latch(
        length,
        thickness,
        width,
        args.double("hookDepth"),
        args.double("rampLength"),
      )
    "o-ring" => @mechanisms.o_ring(diameter, thickness)
    "grooved-shaft" =>
      @mechanisms.grooved_shaft(
        diameter,
        length,
        args.double("grooveWidth"),
        args.double("grooveDepth"),
        args.double("grooveCenter"),
      )
    "bracket" =>
      @mechanisms.l_bracket(
        args.double("legA"),
        args.double("legB"),
        width,
        thickness,
        diameter,
        gusset_mm=args.double("gusset"),
      )
    "u-bracket" =>
      @mechanisms.u_bracket(
        args.double("legA"),
        args.double("legB"),
        width,
        thickness,
        bore,
      )
    "z-bracket" =>
      @mechanisms.z_bracket(
        args.double("legA"),
        args.double("legB"),
        height,
        width,
        thickness,
        bore,
      )
    "boss" =>
      @mechanisms.tapped_boss(
        diameter,
        length,
        width,
        thickness,
        args.double("threadDiameter"),
        args.double("threadPitch"),
        args.double("threadDepth"),
        counterbore_diameter_mm=args.double("counterbore"),
        counterbore_depth_mm=args.double("counterboreDepth"),
      )
    "rack" =>
      @mechanisms.rack_gear(
        args.double("module"),
        args.int("teeth"),
        args.double("baseThickness"),
        thickness,
      )
    "sprocket" => @mechanisms.ansi40_sprocket(args.int("sprocketTeeth"))
    "chain-segment" =>
      @mechanisms.ansi40_chain_segment(args.int("chainPitches"))
    other => {
      @cli.eprintln("error: unknown --part '\{other}'")
      abort("")
    }
  }
  let component = match result {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("evaluated") {
    component.write_step_evaluated(args.string_opt("out"))
    return
  }
  component.write_step(args.string_opt("out"), checked=true)
}
