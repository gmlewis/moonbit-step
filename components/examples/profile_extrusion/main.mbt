///|
/// components/examples/profile_extrusion
///
/// Generate one aluminium-extrusion profile as a STEP file:
///
/// ```bash
/// moon run components/examples/profile_extrusion -- \
///   --profile 2020-b-slot6-a --length 50 -o PROFILE-2020-L50.step
/// ```
///
/// The profiles package does the modelling; this program only parses
/// parameters and writes the result.
async fn main {
  let spec = {
    "profile": @cli.opt_string(short='p', help="Profile: 2020-b-slot6-a"),
    "length": @cli.opt_double(
      50.0,
      short='l',
      help="Extrusion length in mm",
      min=0.0,
      min_exclusive=true,
    ),
    "detail": @cli.opt_string(
      short='d',
      help="Detail: simplified, detailed, full",
    ),
    "orient-to-reference": @cli.flag(
      help="Lay the extrusion along -Y with the section in XZ (the reference file's axis convention)",
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/profile_extrusion",
      description="Generate one extrusion profile STEP model.",
    )
    is Some(args) else {
    return
  }
  let profile = args.string_opt("profile").unwrap_or("2020-b-slot6-a")
  let length = args.double("length")
  let detail = parse_detail(args.string_opt("detail").unwrap_or("detailed"))
  let result : Result[@common.Component, @common.SpecError] = match profile {
    "2020-b-slot6-a" =>
      @profiles.b_slot6_2020_extrusion(
        length,
        detail~,
        orient_to_reference=args.flag("orient-to-reference"),
      )
    other => {
      @cli.eprintln("error: unsupported profile: " + other)
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
  component.write_step(args.string_opt("out"), checked=true)
}

///|
fn parse_detail(text : String) -> @common.DetailLevel {
  match text {
    "simplified" | "simple" => @common.DetailLevel::Simplified
    "full" | "fully-modeled" | "fullymodeled" =>
      @common.DetailLevel::FullyModeled
    _ => @common.DetailLevel::Detailed
  }
}
