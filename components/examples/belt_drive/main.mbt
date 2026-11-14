///|
/// components/examples/belt_drive
///
/// Build a two-pulley GT2 belt drive with a declared belt pitch length:
///
/// ```bash
/// moon run components/examples/belt_drive -- \
///   --teethA 20 --teethB 40 --pitchLength 400 -o belt-drive.step
/// moon run components/examples/belt_drive -- --mode assembly \
///   -o belt-drive-assembly.step
/// ./run-example.sh belt_drive --view       # owner
/// ./run-example.sh --headless belt_drive    # agents
/// ```
///
/// The pulleys use the existing approximate GT2 tooth profile. The belt is a
/// smooth envelope whose inner boundary is the exact open-belt tangent path at
/// the two pitch circles; its pitch length is the declared value. Because the
/// belt teeth are omitted, the envelope overlaps the pulley tooth tips
/// nominally. Belt strength and tooth life are not claimed.
async fn main {
  let spec = {
    "teethA": @cli.opt_int(20, help="Pulley A tooth count"),
    "teethB": @cli.opt_int(40, help="Pulley B tooth count"),
    "pitchLength": @cli.opt_double(
      400.0,
      help="Declared belt pitch length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "beltWidth": @cli.opt_double(
      9.0,
      help="Belt width in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "beltThickness": @cli.opt_double(
      1.5,
      help="Belt envelope thickness in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "boreA": @cli.opt_double(
      5.0,
      help="Pulley A bore in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "boreB": @cli.opt_double(
      8.0,
      help="Pulley B bore in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "mode": @cli.opt_string(
      short='M',
      help="Output mode: flat (default) or assembly",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/belt_drive",
      description="Build a two-pulley GT2 belt drive with a declared pitch length.",
    )
    is Some(args) else {
    return
  }
  let teeth_a = args.int("teethA")
  let teeth_b = args.int("teethB")
  let geom_a = match @motion.gt2_geometry(teeth_a) {
    Ok(g) => g
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let geom_b = match @motion.gt2_geometry(teeth_b) {
    Ok(g) => g
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pitch_length = args.double("pitchLength")
  let center = match
    @mechanisms.belt_center_distance_for_pitch_length_unequal(
      pitch_length,
      geom_a.pitch_diameter_mm,
      geom_b.pitch_diameter_mm,
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pulley_a = match
    @motion.gt2_pulley(teeth_a, args.double("beltWidth"), args.double("boreA")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let pulley_b = match
    @motion.gt2_pulley(teeth_b, args.double("beltWidth"), args.double("boreB")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let belt = match
    @mechanisms.belt_loop_unequal(
      geom_a.pitch_diameter_mm,
      geom_b.pitch_diameter_mm,
      center,
      args.double("beltThickness"),
      args.double("beltWidth"),
    ) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  let assembly = @assemblies.Assembly::new(
      name="gt2-belt-drive",
      description="Two approximate GT2 pulleys and a smooth belt envelope with an exact declared pitch length.",
    )
    .add(
      pulley_a,
      placement=@common.Placement::translation(-center / 2.0, 0.0, 0.0),
      instance_name="pulley-a",
    )
    .add(
      pulley_b,
      placement=@common.Placement::translation(center / 2.0, 0.0, 0.0),
      instance_name="pulley-b",
    )
    .add(belt, instance_name="belt")
  match args.string_opt("mode").unwrap_or("flat") {
    "assembly" => assembly.write_assembly_step(args.string_opt("out"))
    "flat" => assembly.write_step(args.string_opt("out"), checked=true)
    other => {
      @cli.eprintln("error: unsupported mode: " + other)
      abort("")
    }
  }
}
