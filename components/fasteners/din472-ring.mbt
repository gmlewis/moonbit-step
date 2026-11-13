///|
/// Din472Outline is the free-state plan outline of one DIN 472 internal ring.
///
/// DIN 472 fixes the ring's thickness, free outside diameter, lug and back
/// widths, lug-hole diameter, and groove interface, but it does not dimension
/// the outline curve between the back and the lugs. The outline used here is
/// the measured geometry of the CC0 Innerscene "DIN 472 internal circlip
/// 20 mm" model; it is re-encoded as this library's own line/arc loop in the
/// default lugs-toward-+X frame.
pub(all) struct Din472Outline {
  bore_mm : Double
  thickness_mm : Double
  start : @cad.Vec2
  ops : Array[RingOp]
  holes : Array[(Double, Double, Double)]
}

///|
/// din472_outline_20 returns the measured 20 mm internal-ring outline in the
/// default lugs-toward-+X frame.
///
/// The loop is counter-clockwise; the two plier holes sit at
/// `(8.65, +/- 2.2)` with radius 1.0 mm.
fn din472_outline_20() -> Din472Outline {
  {
    bore_mm: 20.0,
    thickness_mm: 1.0,
    start: (10.7272, -0.7),
    ops: [
      RingLine(7.1803, -0.7),
      RingArc(6.5931, -1.7765, 6.7073, -2.9974),
      RingArc(-8.45, 0.0, 6.7073, 2.9974),
      RingArc(6.5931, 1.7765, 7.1803, 0.7),
      RingLine(10.7272, 0.7),
      RingArc(-10.75, 0.0, 10.7272, -0.7),
    ],
    holes: [(8.65, 2.2, 1.0), (8.65, -2.2, 1.0)],
  }
}

///|
/// din472_outline returns the free-state outline for a DIN 472 bore size.
///
/// Only the 20 mm free-state outline has a licensed reference model, so this
/// library encodes that size exactly and rejects the others with an explicit
/// gap. `@standards.din472_size` still carries the verified groove table for
/// every supported bore.
pub fn din472_outline(
  bore_mm : Double,
) -> Result[Din472Outline, @common.SpecError] {
  if (bore_mm - 20.0).abs() < 1.0e-9 {
    return Ok(din472_outline_20())
  }
  Err(
    @common.SpecError::InvalidSize(
      "DIN 472 free-state outline is encoded only for the 20 mm bore; other sizes expose the groove table via @standards.din472_size",
    ),
  )
}

///|
/// din472_segments converts a DIN 472 outline to a counter-clockwise segment
/// loop, splitting every three-point arc into two minor arcs.
fn din472_segments(
  outline : Din472Outline,
) -> Result[Array[@cad.ProfileSegment], @common.SpecError] {
  let out : Array[@cad.ProfileSegment] = []
  let mut cursor = outline.start
  for op in outline.ops {
    match op {
      RingLine(x, y) => {
        let end = (x, y)
        out.push(@cad.SegmentLine(cursor, end))
        cursor = end
      }
      RingArc(mx, my, x, y) => {
        let mid = (mx, my)
        let end = (x, y)
        match ring_circumcentre(cursor, mid, end) {
          Err(e) => return Err(e)
          Ok(centre) => {
            out.push(@cad.SegmentArc(cursor, mid, centre))
            out.push(@cad.SegmentArc(mid, end, centre))
            cursor = end
          }
        }
      }
    }
  }
  Ok(out)
}

///|
/// din472_ring builds a DIN 472 internal retaining ring for a nominal bore
/// diameter.
///
/// The ring lies in the XY plane from `z = 0` to `z = s`, its axis along +Z,
/// and its lugs toward +X. The free-state outline and the two plier holes are
/// modelled; the bore groove is not. The outline is the measured CC0
/// Innerscene "DIN 472 internal circlip 20 mm" model, re-encoded as this
/// library's own line/arc loop; DIN 472 does not dimension that curve. Only
/// the 20 mm size has a licensed reference outline, so other sizes are
/// rejected. Use `@standards.din472_size` for the groove interface of every
/// size.
///
/// The ring is a flat stamped part: sharp edges, no edge breaks, no spring
/// temper, and no load, torque, or fatigue rating.
pub fn din472_ring(
  bore_mm : Double,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.din472_size(bore_mm) {
    Err(e) => Err(e)
    Ok(size) =>
      match din472_outline(bore_mm) {
        Err(e) => Err(e)
        Ok(outline) =>
          match din472_segments(outline) {
            Err(e) => Err(e)
            Ok(segments) => {
              let hole_loops : Array[Array[@cad.ProfileSegment]] = []
              for hole in outline.holes {
                let (cx, cy, radius) = hole
                hole_loops.push(ring_circle_loop(cx, cy, radius))
              }
              let profile = @cad.ExtrudedArcProfile::new(
                segments,
                outline.thickness_mm,
                holes=hole_loops,
              )
              if !profile.validate() {
                return Err(
                  @common.SpecError::InvalidParameter(
                    "DIN 472 retaining-ring outline is not a valid closed loop",
                  ),
                )
              }
              let body = profile.as_shape()
              let features = @common.FeatureRecord::new(
                modeled=[
                  "flat-ring", "inward-lugs", "plier-holes", "free-outside-diameter",
                ],
                approximated=[
                  @common.Approximation::new(
                    feature="outline-between-the-back-and-the-lugs",
                    kind=@common.ApproximationKind::EngineeringDefault,
                    deviation_mm=0.0,
                    control="measured CC0 Innerscene 20 mm reference outline; DIN 472 does not dimension this curve",
                  ),
                ],
                omitted=[
                  @common.Omission::new(
                    feature="edge-breaks",
                    reason="the reference model has sharp edges; no deburring or radius is modelled",
                  ),
                  @common.Omission::new(
                    feature="bore-groove",
                    reason="the groove (d2 x m) is a bore feature; it is declared by the groove-seat connector, not modelled",
                  ),
                  @common.Omission::new(
                    feature="spring-temper-and-load-rating",
                    reason="material condition, installation force, and load or fatigue capacity are not modelled",
                  ),
                ],
              )
              let component = @common.Component::new(
                name="din472-\{@cad.fmt_double(bore_mm, None)}",
                metadata=@common.Metadata::new(
                  designation=size.designation(),
                  standard=@standards.DIN472Size::standard(),
                  family="internal retaining ring",
                  size="\{@cad.fmt_double(bore_mm, None)}",
                  source=@standards.DIN472Size::source(),
                ),
                description="DIN 472 internal retaining ring: a flat stamped ring with two inward lugs, plier holes, and a free outside diameter. Sharp edges; no groove, spring temper, or load rating.",
                features~,
              ).add_layer(body, name="body", color~)
              Ok(with_din472_connectors(component, size, outline))
            }
          }
      }
  }
}

///|
/// with_din472_connectors attaches the two ring faces, the nominal bore, the
/// free outside diameter, the bore-groove datum, and the two plier holes.
fn with_din472_connectors(
  component : @common.Component,
  size : @standards.DIN472Size,
  outline : Din472Outline,
) -> @common.Component {
  let s = outline.thickness_mm
  let half = s / 2.0
  let base = component
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-negative",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        description="ring face at z = 0",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "face-positive",
        placement=@common.Placement::translation(0.0, 0.0, s),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        description="ring face at z = s",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "bore",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.bore_diameter_mm,
        depth_mm=s,
        description="nominal bore (DIN 472 d1); the ring seats inside it and springs outward into the groove",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "free-outer",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=size.free_outer_diameter_mm,
        depth_mm=s,
        description="free outside diameter (DIN 472 d3)",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "groove-seat",
        placement=@common.Placement::translation(0.0, 0.0, half),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::Datum,
        diameter_mm=size.groove_diameter_mm,
        depth_mm=size.groove_width_mm,
        description="bore groove interface (DIN 472 d2 x m); declared, not modelled",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "lug-hole-1",
        placement=@common.Placement::translation(
          outline.holes[0].0,
          outline.holes[0].1,
          half,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=size.lug_hole_mm,
        depth_mm=s,
        description="plier hole 1; the reference model's hole is measured and may differ from d5",
      ),
    )
  base.with_connector_unchecked(
    @common.MateConnector::new(
      "lug-hole-2",
      placement=@common.Placement::translation(
        outline.holes[1].0,
        outline.holes[1].1,
        half,
      ),
      axis=(0.0, 0.0, 1.0),
      kind=@common.MateKind::CylindricalBore,
      gender=@common.MateGender::Female,
      diameter_mm=size.lug_hole_mm,
      depth_mm=s,
      description="plier hole 2; the reference model's hole is measured and may differ from d5",
    ),
  )
}
