///|
/// rev_45mm_outer returns the measured 45 mm U-channel cross-section (enclosed
/// area 339.855 mm2), measured clean-room from the REV vendor STEP
/// `REV-41-1741` at a station between drilled holes.
fn rev_45mm_outer() -> Array[RevSeg] {
  [
    RevArc(18.75, 20.0, 20.456539197, 21.163645978, 20.0, 20.0, 1.25),
    RevLine(20.456539197, 21.163645978, 20.939339828, 21.646446609),
    RevArc(
      20.939339828, 21.646446609, 20.585786438, 22.5, 20.585786438, 22.0, 0.5,
    ),
    RevLine(20.585786438, 22.5, 17.1, 22.5),
    RevArc(17.1, 22.5, 16.6, 22.0, 17.1, 22.0, 0.5),
    RevLine(16.6, 22.0, 16.6, 21.8),
    RevArc(16.6, 21.8, 17.1, 21.3, 17.1, 21.8, 0.5),
    RevLine(17.1, 21.3, 17.65, 21.3),
    RevArc(17.65, 21.3, 17.85, 21.1, 17.65, 21.1, 0.2),
    RevLine(17.85, 21.1, 17.85, 19.0),
    RevArc(17.85, 19.0, 17.35, 18.5, 17.35, 19.0, 0.5),
    RevLine(17.35, 18.5, 12.65, 18.5),
    RevArc(12.65, 18.5, 12.15, 19.0, 12.65, 19.0, 0.5),
    RevLine(12.15, 19.0, 12.15, 21.1),
    RevArc(12.15, 21.1, 12.35, 21.3, 12.35, 21.1, 0.2),
    RevLine(12.35, 21.3, 12.9, 21.3),
    RevArc(12.9, 21.3, 13.4, 21.8, 12.9, 21.8, 0.5),
    RevLine(13.4, 21.8, 13.4, 22.0),
    RevArc(13.4, 22.0, 12.9, 22.5, 12.9, 22.0, 0.5),
    RevLine(12.9, 22.5, -12.9, 22.5),
    RevArc(-12.9, 22.5, -13.4, 22.0, -12.9, 22.0, 0.5),
    RevLine(-13.4, 22.0, -13.4, 21.8),
    RevArc(-13.4, 21.8, -12.9, 21.3, -12.9, 21.8, 0.5),
    RevLine(-12.9, 21.3, -12.35, 21.3),
    RevArc(-12.35, 21.3, -12.15, 21.1, -12.35, 21.1, 0.2),
    RevLine(-12.15, 21.1, -12.15, 19.0),
    RevArc(-12.15, 19.0, -12.65, 18.5, -12.65, 19.0, 0.5),
    RevLine(-12.65, 18.5, -17.35, 18.5),
    RevArc(-17.35, 18.5, -17.85, 19.0, -17.35, 19.0, 0.5),
    RevLine(-17.85, 19.0, -17.85, 21.1),
    RevArc(-17.85, 21.1, -17.65, 21.3, -17.65, 21.1, 0.2),
    RevLine(-17.65, 21.3, -17.1, 21.3),
    RevArc(-17.1, 21.3, -16.6, 21.8, -17.1, 21.8, 0.5),
    RevLine(-16.6, 21.8, -16.6, 22.0),
    RevArc(-16.6, 22.0, -17.1, 22.5, -17.1, 22.0, 0.5),
    RevLine(-17.1, 22.5, -20.585786438, 22.5),
    RevArc(
      -20.585786438, 22.5, -20.939339828, 21.646446609, -20.585786438, 22.0, 0.5,
    ),
    RevLine(-20.939339828, 21.646446609, -20.456539197, 21.163645978),
    RevArc(-20.456539197, 21.163645978, -18.75, 20.0, -20.0, 20.0, 1.25),
    RevArc(-18.75, 20.0, -20.0, 18.75, -20.0, 20.0, 1.25),
    RevArc(-20.0, 18.75, -21.25, 20.0, -20.0, 20.0, 1.25),
    RevArc(-21.25, 20.0, -21.163645978, 20.456539197, -20.0, 20.0, 1.25),
    RevLine(-21.163645978, 20.456539197, -21.646446609, 20.939339828),
    RevArc(
      -21.646446609, 20.939339828, -22.5, 20.585786438, -22.0, 20.585786438, 0.5,
    ),
    RevLine(-22.5, 20.585786438, -22.5, -22.5),
    RevLine(-22.5, -22.5, -20.0, -22.5),
    RevLine(-20.0, -22.5, -20.0, 16.5),
    RevLine(-20.0, 16.5, -11.407106781, 16.5),
    RevArc(
      -11.407106781, 16.5, -11.053553391, 16.646446609, -11.407106781, 17.0, 0.5,
    ),
    RevLine(-11.053553391, 16.646446609, -9.846446609, 17.853553391),
    RevArc(
      -9.846446609, 17.853553391, -9.7, 18.207106781, -10.2, 18.207106781, 0.5,
    ),
    RevLine(-9.7, 18.207106781, -9.7, 20.0),
    RevLine(-9.7, 20.0, 9.7, 20.0),
    RevLine(9.7, 20.0, 9.7, 18.207106781),
    RevArc(
      9.7, 18.207106781, 9.846446609, 17.853553391, 10.2, 18.207106781, 0.5,
    ),
    RevLine(9.846446609, 17.853553391, 11.053553391, 16.646446609),
    RevArc(
      11.053553391, 16.646446609, 11.407106781, 16.5, 11.407106781, 17.0, 0.5,
    ),
    RevLine(11.407106781, 16.5, 20.0, 16.5),
    RevLine(20.0, 16.5, 20.0, -22.5),
    RevLine(20.0, -22.5, 22.5, -22.5),
    RevLine(22.5, -22.5, 22.5, 20.585786438),
    RevArc(
      22.5, 20.585786438, 21.646446609, 20.939339828, 22.0, 20.585786438, 0.5,
    ),
    RevLine(21.646446609, 20.939339828, 21.163645978, 20.456539197),
    RevArc(21.163645978, 20.456539197, 21.25, 20.0, 20.0, 20.0, 1.25),
    RevArc(21.25, 20.0, 20.0, 18.75, 20.0, 20.0, 1.25),
    RevArc(20.0, 18.75, 18.75, 20.0, 20.0, 20.0, 1.25),
  ]
}

///|
/// rev_45mm_loop converts the measured section into a closed analytic loop.
fn rev_45mm_loop() -> Array[@cad.ProfileSegment] {
  rev_45mm_outer().map(fn(seg) {
    match seg {
      RevLine(ax, ay, bx, by) => @cad.SegmentLine((ax, ay), (bx, by))
      RevArc(ax, ay, bx, by, cx, cy, _r) =>
        @cad.SegmentArc((ax, ay), (bx, by), (cx, cy))
    }
  })
}

///|
/// rev_45mm_uchannel builds the REV Robotics 45 x 45 mm U-channel from its
/// measured cross-section.
///
/// Frame: the section is centred on the XY origin, the channel opens along -Y,
/// and the part runs along +Z from `z = 0` to `z = length_mm`. The section is the
/// exact measured U profile: 2.5 mm side walls, a 6 mm back wall with a T-slot
/// on both faces, and the measured corner breaks.
///
/// The vendor part's **Extended Motion Pattern** (dense Ø3.2 and Ø9 holes on
/// 16 mm centres through both side walls and the back wall) is an explicit
/// omission in this builder: the drilled pattern is not modelled. Recorded in
/// `devnotes/hobby-store-measurements.md`.
///
/// Source: https://www.revrobotics.com/45mm-u-channels/ and
/// https://revrobotics.com/content/docs/15mm-Extrusion-DR.pdf (6063-T6, M3
/// hardware, Extended Motion Pattern). SKUs 1755 24 mm through 1740 1 m.
pub fn rev_45mm_uchannel(
  length_mm~ : Double = 440.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("REV 45 mm U-channel length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if length_mm < 10.0 {
    return Err(@common.InvalidDimension("REV 45 mm U-channel is too short"))
  }
  let shape = @cad.ExtrudedArcProfile::new(rev_45mm_loop(), length_mm).as_shape()
  let features = @common.FeatureRecord::new(
    modeled=["measured-45mm-u-section", "double-sided-back-t-slot"],
    approximated=[],
    omitted=[
      @common.Omission::new(
        feature="extended-motion-pattern",
        reason="the dense Ø3.2 and Ø9 hole pattern on 16 mm centres through the side and back walls is not modelled; the measured section and the longitudinal T-slots are",
      ),
    ],
  )
  let length_text = @cad.fmt_double(length_mm, None)
  let name = "rev-45mm-uchannel-\{length_text}"
  let component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="REV Robotics 45 mm U-channel (\{length_text} mm)",
      standard="REV DUO 45 mm U-channel",
      family="REV 45 mm U-channel",
      size="45x45",
      length_mm~,
      material="aluminium 6063-T6",
      source="https://www.revrobotics.com/45mm-u-channels/ | REV DUO 45 x 45 mm U-channel, 6063-T6, M3 hardware, Extended Motion Pattern | section measured clean-room from vendor STEP REV-41-1741",
    ),
    description="REV Robotics 45 x 45 mm U-channel with the measured section and double-sided back T-slot; the drilled motion pattern is not modelled.",
    features~,
  ).add_layer(shape, name="profile", color~)
  Ok(
    component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "open-side",
        placement=@common.Placement::translation(0.0, -22.5, length_mm / 2.0),
        axis=(0.0, -1.0, 0.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=40.0,
        description="channel opening plane on -Y",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-a",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=45.0,
        description="-Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "end-b",
        placement=@common.Placement::translation(0.0, 0.0, length_mm),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=45.0,
        description="+Z end face",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "back-slot",
        placement=@common.Placement::translation(0.0, 22.5, length_mm / 2.0),
        axis=(0.0, 1.0, 0.0),
        kind=@common.MateKind::ProfileSlot,
        diameter_mm=6.0,
        depth_mm=3.0,
        description="outer back-face T-slot",
      ),
    ),
  )
}

///|
/// rev_45mm_family exposes the published U-channel lengths.
pub fn rev_45mm_family() -> Result[@common.DesignFamily, @common.SpecError] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=440.0,
      min_mm=10.0,
      max_mm=2000.0,
      description="channel length",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="rev-45mm-uchannel",
      specs~,
      description="REV DUO 45 x 45 mm U-channels with the measured section.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        rev_45mm_uchannel(length_mm=length)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let mut out = family
  for
    length in [
      24.0, 56.0, 88.0, 152.0, 248.0, 312.0, 376.0, 408.0, 440.0, 1000.0,
    ] {
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
