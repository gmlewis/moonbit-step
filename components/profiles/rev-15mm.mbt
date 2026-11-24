///|
/// RevSeg is one measured segment of the REV Robotics 15 mm extrusion:
/// a straight line or a circular arc (start, end, centre, radius).
priv enum RevSeg {
  RevLine(Double, Double, Double, Double)
  RevArc(Double, Double, Double, Double, Double, Double, Double)
}

///|
/// rev_15_outer returns the measured outer section of the REV 15 x 15 mm
/// extrusion (enclosed area 95.701 mm2, measured clean-room from the vendor
/// STEP `REV-41-1568`, which is prismatic and carries only the central bore).
fn rev_15_outer() -> Array[RevSeg] {
  [
    RevArc(-6.25, 5.0, -6.163645978, 5.456539197, -5.0, 5.0, 1.25),
    RevLine(-6.163645978, 5.456539197, -6.646446609, 5.939339828),
    RevArc(-6.646446609, 5.939339828, -7.5, 5.585786438, -7.0, 5.585786438, 0.5),
    RevLine(-7.5, 5.585786438, -7.5, 2.25),
    RevArc(-7.5, 2.25, -7.0, 1.75, -7.0, 2.25, 0.5),
    RevLine(-7.0, 1.75, -6.8, 1.75),
    RevArc(-6.8, 1.75, -6.3, 2.25, -6.8, 2.25, 0.5),
    RevLine(-6.3, 2.25, -6.3, 2.65),
    RevArc(-6.3, 2.65, -6.1, 2.85, -6.1, 2.65, 0.2),
    RevLine(-6.1, 2.85, -4.0, 2.85),
    RevArc(-4.0, 2.85, -3.5, 2.35, -4.0, 2.35, 0.5),
    RevLine(-3.5, 2.35, -3.5, 2.1),
    RevArc(-3.5, 2.1, -3.0, 1.6, -3.0, 2.1, 0.5),
    RevArc(-3.0, 1.6, -2.0, 0.6, -3.0, 0.6, 1.0),
    RevLine(-2.0, 0.6, -2.0, -0.6),
    RevArc(-2.0, -0.6, -3.0, -1.6, -3.0, -0.6, 1.0),
    RevArc(-3.0, -1.6, -3.5, -2.1, -3.0, -2.1, 0.5),
    RevLine(-3.5, -2.1, -3.5, -2.35),
    RevArc(-3.5, -2.35, -4.0, -2.85, -4.0, -2.35, 0.5),
    RevLine(-4.0, -2.85, -6.1, -2.85),
    RevArc(-6.1, -2.85, -6.3, -2.65, -6.1, -2.65, 0.2),
    RevLine(-6.3, -2.65, -6.3, -2.25),
    RevArc(-6.3, -2.25, -6.8, -1.75, -6.8, -2.25, 0.5),
    RevLine(-6.8, -1.75, -7.0, -1.75),
    RevArc(-7.0, -1.75, -7.5, -2.25, -7.0, -2.25, 0.5),
    RevLine(-7.5, -2.25, -7.5, -5.585786438),
    RevArc(
      -7.5, -5.585786438, -6.646446609, -5.939339828, -7.0, -5.585786438, 0.5,
    ),
    RevLine(-6.646446609, -5.939339828, -6.163645978, -5.456539197),
    RevArc(-6.163645978, -5.456539197, -6.25, -5.0, -5.0, -5.0, 1.25),
    RevArc(-6.25, -5.0, -5.0, -3.75, -5.0, -5.0, 1.25),
    RevArc(-5.0, -3.75, -3.75, -5.0, -5.0, -5.0, 1.25),
    RevArc(-3.75, -5.0, -5.456539197, -6.163645978, -5.0, -5.0, 1.25),
    RevLine(-5.456539197, -6.163645978, -5.939339828, -6.646446609),
    RevArc(
      -5.939339828, -6.646446609, -5.585786438, -7.5, -5.585786438, -7.0, 0.5,
    ),
    RevLine(-5.585786438, -7.5, -2.25, -7.5),
    RevArc(-2.25, -7.5, -1.75, -7.0, -2.25, -7.0, 0.5),
    RevLine(-1.75, -7.0, -1.75, -6.8),
    RevArc(-1.75, -6.8, -2.25, -6.3, -2.25, -6.8, 0.5),
    RevLine(-2.25, -6.3, -2.65, -6.3),
    RevArc(-2.65, -6.3, -2.85, -6.1, -2.65, -6.1, 0.2),
    RevLine(-2.85, -6.1, -2.85, -4.0),
    RevArc(-2.85, -4.0, -2.35, -3.5, -2.35, -4.0, 0.5),
    RevLine(-2.35, -3.5, -2.1, -3.5),
    RevArc(-2.1, -3.5, -1.6, -3.0, -2.1, -3.0, 0.5),
    RevArc(-1.6, -3.0, -0.6, -2.0, -0.6, -3.0, 1.0),
    RevLine(-0.6, -2.0, 0.6, -2.0),
    RevArc(0.6, -2.0, 1.6, -3.0, 0.6, -3.0, 1.0),
    RevArc(1.6, -3.0, 2.1, -3.5, 2.1, -3.0, 0.5),
    RevLine(2.1, -3.5, 2.35, -3.5),
    RevArc(2.35, -3.5, 2.85, -4.0, 2.35, -4.0, 0.5),
    RevLine(2.85, -4.0, 2.85, -6.1),
    RevArc(2.85, -6.1, 2.65, -6.3, 2.65, -6.1, 0.2),
    RevLine(2.65, -6.3, 2.25, -6.3),
    RevArc(2.25, -6.3, 1.75, -6.8, 2.25, -6.8, 0.5),
    RevLine(1.75, -6.8, 1.75, -7.0),
    RevArc(1.75, -7.0, 2.25, -7.5, 2.25, -7.0, 0.5),
    RevLine(2.25, -7.5, 5.585786438, -7.5),
    RevArc(5.585786438, -7.5, 6.085786438, -7.0, 5.585786438, -7.0, 0.5),
    RevArc(6.085786438, -7.0, 5.939339828, -6.646446609, 5.585786438, -7.0, 0.5),
    RevLine(5.939339828, -6.646446609, 5.456539197, -6.163645978),
    RevArc(5.456539197, -6.163645978, 3.75, -5.0, 5.0, -5.0, 1.25),
    RevArc(3.75, -5.0, 5.0, -3.75, 5.0, -5.0, 1.25),
    RevArc(5.0, -3.75, 6.25, -5.0, 5.0, -5.0, 1.25),
    RevArc(6.25, -5.0, 6.163645978, -5.456539197, 5.0, -5.0, 1.25),
    RevLine(6.163645978, -5.456539197, 6.646446609, -5.939339828),
    RevArc(6.646446609, -5.939339828, 7.5, -5.585786438, 7.0, -5.585786438, 0.5),
    RevLine(7.5, -5.585786438, 7.5, -2.25),
    RevArc(7.5, -2.25, 7.0, -1.75, 7.0, -2.25, 0.5),
    RevLine(7.0, -1.75, 6.8, -1.75),
    RevArc(6.8, -1.75, 6.3, -2.25, 6.8, -2.25, 0.5),
    RevLine(6.3, -2.25, 6.3, -2.65),
    RevArc(6.3, -2.65, 6.1, -2.85, 6.1, -2.65, 0.2),
    RevLine(6.1, -2.85, 4.0, -2.85),
    RevArc(4.0, -2.85, 3.5, -2.35, 4.0, -2.35, 0.5),
    RevLine(3.5, -2.35, 3.5, -2.1),
    RevArc(3.5, -2.1, 3.0, -1.6, 3.0, -2.1, 0.5),
    RevArc(3.0, -1.6, 2.0, -0.6, 3.0, -0.6, 1.0),
    RevLine(2.0, -0.6, 2.0, 0.6),
    RevArc(2.0, 0.6, 3.0, 1.6, 3.0, 0.6, 1.0),
    RevArc(3.0, 1.6, 3.5, 2.1, 3.0, 2.1, 0.5),
    RevLine(3.5, 2.1, 3.5, 2.35),
    RevArc(3.5, 2.35, 4.0, 2.85, 4.0, 2.35, 0.5),
    RevLine(4.0, 2.85, 6.1, 2.85),
    RevArc(6.1, 2.85, 6.3, 2.65, 6.1, 2.65, 0.2),
    RevLine(6.3, 2.65, 6.3, 2.25),
    RevArc(6.3, 2.25, 6.8, 1.75, 6.8, 2.25, 0.5),
    RevLine(6.8, 1.75, 7.0, 1.75),
    RevArc(7.0, 1.75, 7.5, 2.25, 7.0, 2.25, 0.5),
    RevLine(7.5, 2.25, 7.5, 5.585786438),
    RevArc(7.5, 5.585786438, 6.646446609, 5.939339828, 7.0, 5.585786438, 0.5),
    RevLine(6.646446609, 5.939339828, 6.163645978, 5.456539197),
    RevArc(6.163645978, 5.456539197, 6.25, 5.0, 5.0, 5.0, 1.25),
    RevArc(6.25, 5.0, 5.0, 3.75, 5.0, 5.0, 1.25),
    RevArc(5.0, 3.75, 3.75, 5.0, 5.0, 5.0, 1.25),
    RevArc(3.75, 5.0, 5.456539197, 6.163645978, 5.0, 5.0, 1.25),
    RevLine(5.456539197, 6.163645978, 5.939339828, 6.646446609),
    RevArc(5.939339828, 6.646446609, 6.085786438, 7.0, 5.585786438, 7.0, 0.5),
    RevArc(6.085786438, 7.0, 5.585786438, 7.5, 5.585786438, 7.0, 0.5),
    RevLine(5.585786438, 7.5, 2.25, 7.5),
    RevArc(2.25, 7.5, 1.75, 7.0, 2.25, 7.0, 0.5),
    RevLine(1.75, 7.0, 1.75, 6.8),
    RevArc(1.75, 6.8, 2.25, 6.3, 2.25, 6.8, 0.5),
    RevLine(2.25, 6.3, 2.65, 6.3),
    RevArc(2.65, 6.3, 2.85, 6.1, 2.65, 6.1, 0.2),
    RevLine(2.85, 6.1, 2.85, 4.0),
    RevArc(2.85, 4.0, 2.35, 3.5, 2.35, 4.0, 0.5),
    RevLine(2.35, 3.5, 2.1, 3.5),
    RevArc(2.1, 3.5, 1.6, 3.0, 2.1, 3.0, 0.5),
    RevArc(1.6, 3.0, 0.6, 2.0, 0.6, 3.0, 1.0),
    RevLine(0.6, 2.0, -0.6, 2.0),
    RevArc(-0.6, 2.0, -1.6, 3.0, -0.6, 3.0, 1.0),
    RevArc(-1.6, 3.0, -2.1, 3.5, -2.1, 3.0, 0.5),
    RevLine(-2.1, 3.5, -2.35, 3.5),
    RevArc(-2.35, 3.5, -2.85, 4.0, -2.35, 4.0, 0.5),
    RevLine(-2.85, 4.0, -2.85, 6.1),
    RevArc(-2.85, 6.1, -2.65, 6.3, -2.65, 6.1, 0.2),
    RevLine(-2.65, 6.3, -2.25, 6.3),
    RevArc(-2.25, 6.3, -1.75, 6.8, -2.25, 6.8, 0.5),
    RevLine(-1.75, 6.8, -1.75, 7.0),
    RevArc(-1.75, 7.0, -2.25, 7.5, -2.25, 7.0, 0.5),
    RevLine(-2.25, 7.5, -5.585786438, 7.5),
    RevArc(-5.585786438, 7.5, -5.939339828, 6.646446609, -5.585786438, 7.0, 0.5),
    RevLine(-5.939339828, 6.646446609, -5.456539197, 6.163645978),
    RevArc(-5.456539197, 6.163645978, -3.75, 5.0, -5.0, 5.0, 1.25),
    RevArc(-3.75, 5.0, -5.0, 3.75, -5.0, 5.0, 1.25),
    RevArc(-5.0, 3.75, -6.25, 5.0, -5.0, 5.0, 1.25),
  ]
}

///|
/// rev_15_loop converts the measured segments into a closed analytic loop.
fn rev_15_loop() -> Array[@cad.ProfileSegment] {
  rev_15_outer().map(fn(seg) {
    match seg {
      RevLine(ax, ay, bx, by) => @cad.SegmentLine((ax, ay), (bx, by))
      RevArc(ax, ay, bx, by, cx, cy, _r) =>
        @cad.SegmentArc((ax, ay), (bx, by), (cx, cy))
    }
  })
}

///|
/// The REV Robotics DUO 15 mm extrusion series: 15 x 15 mm section, a 5.7 mm
/// slot on each face, and a central 2.5 mm through bore.
///
/// Frame: the section is centred on the XY origin and runs along +Z from
/// `z = 0` to `z = length_mm`. The outer section and central bore are the exact
/// measured profiles of the vendor STEP, so the flat STEP is one closed solid.
/// The published 5 x 2.54 mm M3-tappable end holes are an end-face pattern that
/// the vendor extrusion STEP does not carry (its solid is prismatic); they are
/// declared by `Threaded` connectors at the end faces.
///
/// Source: https://www.revrobotics.com/15mm-extrusions/ and
/// https://www.revrobotics.com/content/docs/15mm-Extrusion-DR.pdf
/// (6063-T5, 15 x 15 mm, 5.7 mm slot, REV-41-1568 120 mm, -1431 225 mm,
/// -1432 420 mm, -1017 1000 mm).
pub fn rev_15mm_extrusion(
  length_mm~ : Double = 120.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("REV 15 mm extrusion length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if length_mm < 10.0 {
    return Err(@common.InvalidDimension("REV 15 mm extrusion is too short"))
  }
  let holes : Array[Array[@cad.ProfileSegment]] = [
    @common.circle_loop(0.0, 0.0, rev_15_bore_radius_mm),
  ]
  let shape = @cad.ExtrudedArcProfile::new(rev_15_loop(), length_mm, holes~).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["measured-15mm-section", "face-slots", "central-through-bore"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="end-tap-drills",
        reason="the 5 x 2.54 mm M3-tappable end-face holes are declared by Threaded connectors; the vendor extrusion STEP is prismatic and does not carry them",
      ),
    ],
  )
  let length_text = @cad.fmt_double(length_mm, None)
  let name = "rev-15mm-extrusion-\{length_text}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="REV Robotics 15 mm extrusion (\{length_text} mm)",
      standard="REV DUO 15 mm build system",
      family="REV 15 mm extrusion",
      size="15x15",
      length_mm~,
      material="aluminium 6063-T5, clear anodized",
      source="https://www.revrobotics.com/15mm-extrusions/ | REV DUO 15 x 15 mm extrusion, 5.7 mm slot, central 2.5 mm bore, 5 x 2.54 mm M3-tappable ends | section measured clean-room from vendor STEP REV-41-1568",
    ),
    description="REV Robotics 15 x 15 mm extrusion with the measured section (5.7 mm face slots and the central through bore).",
    features~,
  ).add_layer(shape, name="profile", color~)
  let mut out = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=15.0,
        description="-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=15.0,
        description="+Z end face",
      ),
    )
  let mut index = 0
  for corner in [(5.0, 5.0), (-5.0, 5.0), (-5.0, -5.0), (5.0, -5.0)] {
    index += 1
    out = out.with_connector_unchecked(
      @common.MateConnector::new(
        "end-tap-\{index}",
        placement=@common.Placement::translation(corner.0, corner.1, length_mm),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::Threaded,
        gender=@common.MateGender::Female,
        diameter_mm=2.54,
        depth_mm=10.0,
        description="M3-tappable end hole (2.54 mm)",
      ),
    )
  }
  Ok(out)
}

///|
/// The measured central bore radius of the REV 15 mm extrusion, in mm.
let rev_15_bore_radius_mm : Double = 1.25

///|
/// rev_15mm_family exposes the published REV 15 mm extrusion lengths.
pub fn rev_15mm_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=120.0,
      min_mm=10.0,
      max_mm=2000.0,
      description="extrusion length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="rev-15mm-extrusion",
      specs~,
      description="REV DUO 15 x 15 mm extrusions with the measured section.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        rev_15mm_extrusion(length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for length in [120.0, 225.0, 420.0, 1000.0] {
    out = match
      out.with_variant("\{@cad.fmt_double(length, None)}mm", [
        ("length", length),
      ]) {
      Ok(next) => next
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
