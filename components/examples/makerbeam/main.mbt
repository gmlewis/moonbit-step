///|
/// components/examples/makerbeam
///
/// Generate a cut-to-length MakerBeam 10 x 10 mm extrusion:
///
/// ```bash
/// moon run components/examples/makerbeam -- --length 100 -o makerbeam.step
/// moon run components/examples/makerbeam -- --length 250 --cornerRadius 0.2 -o mb.step
/// ```
///
/// The section is MakerBeam article 100168. No end tapping, anodising, or
/// strength claim is made.
async fn main {
  let spec = {
    "length": @cli.opt_double(100.0, help="Extrusion length in mm", min=0.0),
    "cornerRadius": @cli.opt_double(
      0.0,
      help="Outer corner radius in mm (0 = sharp dimensioned outline)",
      min=0.0,
    ),
    "out": @cli.opt_string(short='o', help="Write STEP to this path"),
    "bbox": @cli.flag(help="Print the bounding box to stderr"),
  }
  guard @cli.parse(
      spec,
      prog="components/examples/makerbeam",
      description="Generate a MakerBeam 10 x 10 mm extrusion.",
    )
    is Some(args) else {
    return
  }
  let base = @profiles.MakerBeamProfile::mb_1010()
  let radius = args.double("cornerRadius")
  let profile = if radius <= 0.0 {
    base
  } else {
    match
      @profiles.MakerBeamProfile::custom(
        name=base.name,
        size_mm=base.size_mm,
        slot_width_mm=base.slot_width_mm,
        lip_thickness_mm=base.lip_thickness_mm,
        core_width_mm=base.core_width_mm,
        bore_diameter_mm=base.bore_diameter_mm,
        lip_undercut_half_mm=base.lip_undercut_half_mm,
        floor_undercut_half_mm=base.floor_undercut_half_mm,
        corner_radius_mm=radius,
      ) {
      Ok(p) => p
      Err(e) => {
        @cli.eprintln("error: " + e.message())
        abort("")
      }
    }
  }
  let component = match
    @profiles.makerbeam_extrusion(profile, args.double("length")) {
    Ok(c) => c
    Err(e) => {
      @cli.eprintln("error: " + e.message())
      abort("")
    }
  }
  if args.flag("bbox") {
    let (x0, x1, y0, y1, z0, z1) = component.bounding_box()
    @cli.eprintln("bbox: x=[\{x0}, \{x1}] y=[\{y0}, \{y1}] z=[\{z0}, \{z1}]")
  }
  component.write_step(args.string_opt("out"), checked=true)
}
