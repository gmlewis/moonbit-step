///|
/// RingOp is one segment of a retaining-ring outline.
///
/// `RingLine` ends at `(x, y)`. `RingArc` passes through the midpoint
/// `(mx, my)` and ends at `(x, y)`; the builder recovers the circle and splits
/// the arc into two minor arcs so the extrusion compiler can represent it.
pub(all) enum RingOp {
  RingLine(Double, Double)
  RingArc(Double, Double, Double, Double)
}

///|
/// Din471Outline is the free-state plan outline of one DIN 471 type A ring.
///
/// The outline is the published reference model's own geometry (see the
/// attribution in `din471_ring`). DIN 471 fixes the ring's thickness, nominal
/// bore, lug size, and hole diameter but does not dimension the outline
/// between the back and the lugs, so the reference model supplies that curve.
pub(all) struct Din471Outline {
  shaft_mm : Double
  thickness_mm : Double
  start : @cad.Vec2
  ops : Array[RingOp]
  holes : Array[(Double, Double, Double)]
}

///|
fn din471_outline_10() -> Din471Outline {
  {
    shaft_mm: 10.0,
    thickness_mm: 1.0,
    start: (4.1213, -4.1346),
    ops: [
      RingLine(5.9421, -4.1346),
      RingArc(6.7601, -3.892, 7.3134, -3.2426),
      RingArc(7.7312, -2.0562, 7.958, -0.819),
      RingLine(4.5756, -0.819),
      RingArc(-4.6483, 0.0, 4.5756, 0.819),
      RingLine(7.958, 0.819),
      RingArc(7.7312, 2.0562, 7.3134, 3.2426),
      RingArc(6.7601, 3.892, 5.9421, 4.1346),
      RingLine(4.1213, 4.1346),
      RingArc(-6.5794, 0.0, 4.1213, -4.1346),
    ],
    holes: [(5.7, 2.5, 0.75), (5.7, -2.5, 0.75)],
  }
}

///|
fn din471_outline_12() -> Din471Outline {
  {
    shaft_mm: 12.0,
    thickness_mm: 1.0,
    start: (5.498, 0.15),
    ops: [
      RingLine(8.758, 0.1499),
      RingArc(8.6548, 1.3486, 8.3884, 2.5218),
      RingArc(8.1164, 2.9619, 7.661, 3.2071),
      RingLine(6.0001, 3.6),
      RingArc(5.5769, 3.8145, 5.3002, 4.2),
      RingArc(-7.3, -0.0182, 5.3222, -4.17),
      RingArc(5.5945, -3.8059, 5.9999, -3.6),
      RingLine(7.6607, -3.2072),
      RingArc(8.1162, -2.962, 8.3882, -2.522),
      RingArc(8.6547, -1.3488, 8.758, -0.1501),
      RingLine(5.498, -0.15),
      RingArc(-5.5, 0.0004, 5.498, 0.15),
    ],
    holes: [(7.1199, -1.54, 0.85), (7.1201, 1.54, 0.85)],
  }
}

///|
fn din471_outline_14() -> Din471Outline {
  {
    shaft_mm: 14.0,
    thickness_mm: 1.0,
    start: (6.3983, 0.147),
    ops: [
      RingLine(9.8983, 0.1832),
      RingArc(9.745, 1.7456, 9.3466, 3.2642),
      RingArc(9.0738, 3.6757, 8.6374, 3.9065),
      RingLine(6.9988, 4.3024),
      RingArc(6.5247, 4.4807, 6.1987, 4.8684),
      RingArc(-8.6, -0.0018, 6.2013, -4.864),
      RingArc(6.55, -4.4632, 7.0547, -4.2976),
      RingLine(8.6951, -3.8348),
      RingArc(9.1114, -3.5982, 9.3701, -3.1951),
      RingArc(9.7526, -1.7016, 9.8986, -0.1668),
      RingLine(6.3984, -0.1425),
      RingArc(-6.4, -0.0012, 6.3983, 0.147),
    ],
    holes: [(8.2005, -1.7972, 0.85), (8.1995, 1.8028, 0.85)],
  }
}

///|
fn din471_outline_16() -> Din471Outline {
  {
    shaft_mm: 16.0,
    thickness_mm: 1.0,
    start: (7.9978, -4.65),
    ops: [
      RingLine(9.8012, -4.1482),
      RingArc(10.2219, -3.9097, 10.4815, -3.5017),
      RingArc(10.8904, -1.8774, 11.049, -0.21),
      RingLine(7.349, -0.1212),
      RingArc(-7.35, 0.0, 7.349, 0.1212),
      RingLine(11.049, 0.21),
      RingArc(10.8904, 1.8774, 10.4815, 3.5017),
      RingArc(10.2219, 3.9097, 9.8012, 4.1482),
      RingLine(7.9978, 4.65),
      RingArc(7.5499, 4.7805, 7.21, 5.1),
      RingArc(-3.0637, 8.7733, -9.55, 0.0),
      RingArc(-3.0637, -8.7733, 7.21, -5.1),
      RingArc(7.5499, -4.7805, 7.9978, -4.65),
    ],
    holes: [(9.15, -2.0, 0.85), (9.15, 2.0, 0.85)],
  }
}

///|
fn din471_outline_18() -> Din471Outline {
  {
    shaft_mm: 18.0,
    thickness_mm: 1.2,
    start: (10.7415, -4.6379),
    ops: [
      RingArc(11.1509, -4.4136, 11.4139, -4.0278),
      RingArc(11.96, -2.1453, 12.1976, -0.1996),
      RingLine(8.2976, -0.2),
      RingArc(-8.3, -0.0021, 8.2976, 0.2),
      RingLine(12.1976, 0.2004),
      RingArc(11.9049, 2.3991, 11.2189, 4.5084),
      RingLine(8.7656, 5.1751),
      RingArc(8.3188, 5.3776, 8.0222, 5.7682),
      RingArc(-10.7, -0.0024, 8.0236, -5.7683),
      RingArc(8.3202, -5.3777, 8.7668, -5.175),
      RingLine(10.7415, -4.6379),
    ],
    holes: [(10.1997, 2.3002, 1.0), (10.2003, -2.2998, 1.0)],
  }
}

///|
fn din471_outline_20() -> Din471Outline {
  {
    shaft_mm: 20.0,
    thickness_mm: 1.2,
    start: (9.2986, -0.1602),
    ops: [
      RingArc(-9.3, -0.002, 9.2986, 0.1602),
      RingLine(13.2986, 0.2337),
      RingArc(13.0287, 2.6749, 12.3145, 5.0249),
      RingLine(9.7099, 5.753),
      RingArc(9.2202, 5.9772, 8.9177, 6.4229),
      RingArc(-11.9, -0.0023, 8.9191, -6.4229),
      RingArc(9.2215, -5.9771, 9.7112, -5.7529),
      RingLine(11.8325, -5.1593),
      RingArc(12.2431, -4.9295, 12.5031, -4.5374),
      RingArc(13.0792, -2.418, 13.2986, -0.2328),
      RingLine(9.2986, -0.1602),
    ],
    holes: [(11.1997, 2.5002, 1.0), (11.2002, -2.4998, 1.0)],
  }
}

///|
fn din471_outline_22() -> Din471Outline {
  {
    shaft_mm: 22.0,
    thickness_mm: 1.2,
    start: (10.0827, -6.8387),
    ops: [
      RingArc(10.3353, -6.5356, 10.6855, -6.3538),
      RingLine(12.8908, -5.7455),
      RingArc(13.2984, -5.5207, 13.56, -5.1357),
      RingArc(14.2397, -2.735, 14.4978, -0.2534),
      RingLine(10.2978, -0.2135),
      RingArc(-10.3, 0.0, 10.2978, 0.2135),
      RingLine(14.4978, 0.2534),
      RingArc(14.2397, 2.735, 13.56, 5.1357),
      RingArc(13.2984, 5.5207, 12.8908, 5.7455),
      RingLine(10.6855, 6.3538),
      RingArc(10.3353, 6.5356, 10.0827, 6.8387),
      RingArc(-13.1, 0.0, 10.0827, -6.8387),
    ],
    holes: [(12.3, -2.75, 1.0), (12.3, 2.75, 1.0)],
  }
}

///|
fn din471_outline_24() -> Din471Outline {
  {
    shaft_mm: 24.0,
    thickness_mm: 1.2,
    start: (13.7647, -6.2178),
    ops: [
      RingArc(14.1732, -5.9964, 14.4375, -5.6144),
      RingArc(15.1956, -3.0094, 15.4876, -0.3121),
      RingLine(11.0876, -0.1561),
      RingArc(-11.0886, 0.0, 11.0876, 0.1561),
      RingLine(15.4876, 0.3121),
      RingArc(15.1956, 3.0094, 14.4375, 5.6144),
      RingArc(14.1732, 5.9964, 13.7647, 6.2178),
      RingLine(11.7665, 6.7542),
      RingArc(11.2834, 6.9037, 10.9351, 7.2705),
      RingArc(-14.0886, 0.0, 10.9351, -7.2705),
      RingArc(11.2834, -6.9037, 11.7665, -6.7542),
      RingLine(13.7647, -6.2178),
    ],
    holes: [(13.25, 3.0, 1.0), (13.25, -3.0, 1.0)],
  }
}

///|
fn din471_outline_26() -> Din471Outline {
  {
    shaft_mm: 26.0,
    thickness_mm: 1.2,
    start: (14.8315, -6.521),
    ops: [
      RingArc(15.2313, -6.2976, 15.4897, -5.9193),
      RingArc(16.2952, -3.1197, 16.5989, -0.2223),
      RingLine(12.0989, -0.1571),
      RingArc(-0.1051, -12.0995, -12.0999, 0.053),
      RingArc(-0.1051, 12.2055, 12.0989, 0.2631),
      RingLine(16.5989, 0.3283),
      RingArc(16.2952, 3.2257, 15.4897, 6.0253),
      RingArc(15.2313, 6.4036, 14.8315, 6.627),
      RingLine(13.0012, 7.1502),
      RingArc(12.4555, 7.2829, 12.0012, 7.613),
      RingArc(-15.1999, 0.053, 12.0012, -7.507),
      RingArc(12.4555, -7.1769, 13.0012, -7.0442),
      RingLine(14.8315, -6.521),
    ],
    holes: [(14.3012, 3.253, 1.0), (14.3012, -3.147, 1.0)],
  }
}

///|
fn din471_outline_28() -> Din471Outline {
  {
    shaft_mm: 28.0,
    thickness_mm: 1.5,
    start: (12.9483, 0.2098),
    ops: [
      RingLine(17.6484, 0.3128),
      RingArc(17.3269, 3.3676, 16.4807, 6.3205),
      RingArc(16.2118, 6.7095, 15.7942, 6.9314),
      RingLine(13.7322, 7.4575),
      RingArc(13.1852, 7.702, 12.7012, 8.055),
      RingArc(-16.15, 0.0, 12.7012, -8.055),
      RingArc(13.1852, -7.702, 13.7322, -7.4575),
      RingLine(15.7942, -6.9314),
      RingArc(16.2118, -6.7095, 16.4807, -6.3205),
      RingArc(17.3269, -3.3676, 17.6483, -0.3128),
      RingLine(12.9483, -0.2098),
      RingArc(-12.95, 0.0, 12.9483, 0.2098),
    ],
    holes: [(15.2001, 3.4, 1.0), (15.2, -3.4, 1.0)],
  }
}

///|
fn din471_outline_30() -> Din471Outline {
  {
    shaft_mm: 30.0,
    thickness_mm: 1.5,
    start: (17.6469, -7.0418),
    ops: [
      RingArc(18.6243, -3.7595, 18.9966, -0.355),
      RingLine(13.9966, -0.276),
      RingArc(-13.9994, 0.0, 13.9966, 0.276),
      RingLine(18.9966, 0.355),
      RingArc(18.6243, 3.7595, 17.6469, 7.0418),
      RingArc(17.3789, 7.4218, 16.968, 7.6394),
      RingLine(14.5822, 8.2553),
      RingArc(14.0253, 8.5855, 13.6395, 9.1054),
      RingArc(-17.5994, 0.0, 13.6395, -9.1054),
      RingArc(14.0253, -8.5855, 14.5822, -8.2553),
      RingLine(16.968, -7.6394),
      RingArc(17.3789, -7.4218, 17.6469, -7.0418),
    ],
    holes: [(16.3679, -3.7076, 1.0), (16.3679, 3.7076, 1.0)],
  }
}

///|
fn din471_outline_32() -> Din471Outline {
  {
    shaft_mm: 32.0,
    thickness_mm: 1.5,
    start: (17.85, -7.9776),
    ops: [
      RingArc(18.2554, -7.759, 18.5198, -7.382),
      RingArc(19.5474, -3.9212, 19.9341, -0.3318),
      RingLine(14.7341, -0.2904),
      RingArc(-14.7369, 0.0, 14.7341, 0.2904),
      RingLine(19.9341, 0.3318),
      RingArc(19.5474, 3.9212, 18.5198, 7.382),
      RingArc(18.2554, 7.759, 17.85, 7.9776),
      RingLine(15.4868, 8.6115),
      RingArc(14.8458, 8.9745, 14.3796, 9.545),
      RingArc(-18.4079, 0.0, 14.3796, -9.545),
      RingArc(14.8458, -8.9745, 15.4868, -8.6115),
      RingLine(17.85, -7.9776),
    ],
    holes: [(17.3207, 3.9, 1.25), (17.3207, -3.9, 1.25)],
  }
}

///|
fn din471_outline_34() -> Din471Outline {
  {
    shaft_mm: 34.0,
    thickness_mm: 1.5,
    start: (21.1723, 0.4026),
    ops: [
      RingArc(20.756, 4.1973, 19.6652, 7.8556),
      RingArc(19.3954, 8.2368, 18.9819, 8.454),
      RingLine(16.6191, 9.0521),
      RingArc(16.0305, 9.3414, 15.5672, 9.8056),
      RingArc(-19.6161, 0.0, 15.5672, -9.8056),
      RingArc(16.0305, -9.3414, 16.6191, -9.0521),
      RingLine(18.9819, -8.454),
      RingArc(19.3954, -8.2368, 19.6652, -7.8556),
      RingArc(20.756, -4.1973, 21.1723, -0.4026),
      RingLine(15.811, -0.3996),
      RingArc(-15.8161, 0.0, 15.811, 0.3996),
      RingLine(21.1723, 0.4026),
    ],
    holes: [(18.3, -4.1, 1.25), (18.3, 4.1, 1.25)],
  }
}

///|
/// din471_outline returns the free-state outline for a DIN 471 type A size.
///
/// The outlines are the published FreeCAD-library model geometry (CC BY 3.0,
/// by nachotineo), distributed by step.parts as the `din471_retaining_ring_m*`
/// models, and independently re-encoded in the MIT pythonparts model. The
/// model bores differ from DIN 471's d3 by up to 0.13 mm in some sizes; the
/// standard table in `@standards.din471_size` is authoritative for the groove
/// fit.
pub fn din471_outline(
  shaft_mm : Double,
) -> Result[Din471Outline, @common.SpecError] {
  let outlines : Array[(Double, () -> Din471Outline)] = [
    (10.0, din471_outline_10),
    (12.0, din471_outline_12),
    (14.0, din471_outline_14),
    (16.0, din471_outline_16),
    (18.0, din471_outline_18),
    (20.0, din471_outline_20),
    (22.0, din471_outline_22),
    (24.0, din471_outline_24),
    (26.0, din471_outline_26),
    (28.0, din471_outline_28),
    (30.0, din471_outline_30),
    (32.0, din471_outline_32),
    (34.0, din471_outline_34),
  ]
  for entry in outlines {
    let (size, build) = entry
    if (size - shaft_mm).abs() < 1.0e-9 {
      return Ok(build())
    }
  }
  Err(
    @common.SpecError::InvalidSize(
      "no DIN 471 outline for a \{shaft_mm} mm shaft (available: 10 to 34 mm even sizes)",
    ),
  )
}

///|
/// ring_circumcentre returns the centre of the circle through three points.
fn ring_circumcentre(
  a : @cad.Vec2,
  m : @cad.Vec2,
  b : @cad.Vec2,
) -> Result[@cad.Vec2, @common.SpecError] {
  let ax = a.0
  let ay = a.1
  let mx = m.0
  let my = m.1
  let bx = b.0
  let by = b.1
  let d = 2.0 * (ax * (my - by) + mx * (by - ay) + bx * (ay - my))
  if d.abs() < 1.0e-12 {
    return Err(
      @common.SpecError::InvalidParameter(
        "degenerate retaining-ring arc: the three points are collinear",
      ),
    )
  }
  let aa = ax * ax + ay * ay
  let mm = mx * mx + my * my
  let bb = bx * bx + by * by
  let ux = (aa * (my - by) + mm * (by - ay) + bb * (ay - my)) / d
  let uy = (aa * (bx - mx) + mm * (ax - bx) + bb * (mx - ax)) / d
  Ok((ux, uy))
}

///|
/// ring_circle_loop returns a counter-clockwise circle as four 90 degree
/// arcs, which the arc compiler turns into one analytic cylindrical hole.
fn ring_circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let right = (cx + radius, cy)
  let top = (cx, cy + radius)
  let left = (cx - radius, cy)
  let bottom = (cx, cy - radius)
  let centre = (cx, cy)
  [
    @cad.SegmentArc(right, top, centre),
    @cad.SegmentArc(top, left, centre),
    @cad.SegmentArc(left, bottom, centre),
    @cad.SegmentArc(bottom, right, centre),
  ]
}

///|
/// din471_segments converts an outline to a counter-clockwise segment loop.
///
/// Each three-point arc is split at its midpoint into two minor arcs, which is
/// what the extrusion compiler accepts (it rejects a single arc whose sweep
/// exceeds 180 degrees).
fn din471_segments(
  outline : Din471Outline,
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
/// din471_ring builds a DIN 471 type A external retaining ring for a nominal
/// shaft diameter.
///
/// The ring lies in the XY plane from `z = 0` to `z = s`, its axis along +Z,
/// the lugs toward +X. The free-state outline and the two plier holes are
/// modelled; the shaft groove is not. The outline is the published reference
/// model geometry (FreeCAD-library, CC BY 3.0, by nachotineo; step.parts
/// distribution), which matches DIN 471's thickness, lug size, and hole
/// diameter but differs from its nominal free bore `d3` by up to 0.13 mm in
/// some sizes. Use `@standards.din471_size` for the groove interface.
///
/// The ring is a flat stamped part: sharp edges, no edge breaks, no spring
/// temper, and no load, torque, or fatigue rating.
pub fn din471_ring(
  shaft_mm : Double,
  detail~ : @common.DetailLevel = Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  match @standards.din471_size(shaft_mm) {
    Err(e) => Err(e)
    Ok(size) =>
      match din471_outline(shaft_mm) {
        Err(e) => Err(e)
        Ok(outline) =>
          match din471_segments(outline) {
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
                    "retaining-ring outline is not a valid closed loop",
                  ),
                )
              }
              let body = profile.as_shape()
              let features = @common.FeatureRecord::new(
                modeled=["flat-ring", "lugs", "plier-holes", "free-bore"],
                approximated=[
                  @common.Approximation::new(
                    feature="outline-between-the-back-and-the-lugs",
                    kind=@common.ApproximationKind::EngineeringDefault,
                    deviation_mm=0.0,
                    control="published reference model outline; DIN 471 does not dimension this curve",
                  ),
                ],
                omitted=[
                  @common.Omission::new(
                    feature="edge-breaks",
                    reason="the reference model has sharp edges; no deburring or radius is modelled",
                  ),
                  @common.Omission::new(
                    feature="shaft-groove",
                    reason="the groove (d2 x m) is a shaft feature; it is declared by the groove-seat connector, not modelled",
                  ),
                  @common.Omission::new(
                    feature="spring-temper-and-load-rating",
                    reason="material condition, installation force, and load or fatigue capacity are not modelled",
                  ),
                ],
              )
              let component = @common.Component::new(
                name="din471-A\{@cad.fmt_double(shaft_mm, None)}",
                metadata=@common.Metadata::new(
                  designation=size.designation(),
                  standard=@standards.DIN471Size::standard(),
                  family="external retaining ring",
                  size="A\{@cad.fmt_double(shaft_mm, None)}",
                  source=@standards.DIN471Size::source(),
                ),
                description="DIN 471 type A external retaining ring: a flat stamped ring with two lugs, plier holes, and a free bore. Sharp edges; no groove, spring temper, or load rating.",
                features~,
              ).add_layer(body, name="body", color~)
              Ok(with_din471_connectors(component, size, outline))
            }
          }
      }
  }
}

///|
/// with_din471_connectors attaches the two ring faces, the free bore, the
/// shaft-groove datum, and the two plier holes.
fn with_din471_connectors(
  component : @common.Component,
  size : @standards.DIN471Size,
  outline : Din471Outline,
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
        diameter_mm=size.free_inner_diameter_mm,
        depth_mm=s,
        description="free inner diameter (DIN 471 d3); the installed ring opens onto the groove",
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
        description="shaft groove interface (DIN 471 d2 x m); declared, not modelled",
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
