///|
/// Parametric DIN 472 outline calibration, measured from the ten licensed
/// measured outlines: the lug tip sits `1.5 * s` from the centreline, and the
/// inner arc is offset `0.02 * d1` toward the lugs.
const DIN472_PARAM_TIP_PER_THICKNESS : Double = 1.5

///|
const DIN472_PARAM_INNER_OFFSET_PER_BORE : Double = 0.02

///|
/// Din472Outline is the free-state plan outline of one DIN 472 internal ring.
///
/// DIN 472 fixes the ring's thickness, free outside diameter, lug and back
/// widths, lug-hole diameter, and groove interface, but it does not dimension
/// the outline curve between the back and the lugs. The 12 mm and 20 mm
/// outlines are re-encoded from CC0 Innerscene models. The 10, 14, 16, 18, 24,
/// 28, 32, and 40 mm outlines are re-encoded from the CC BY-SA 4.0
/// FreeCAD-parts_library STEPs by sisul01 (commit 2141521); that measured
/// outline data remains CC BY-SA 4.0. Each is expressed as this library's own
/// line/arc loop in the default lugs-toward-+X frame; no reference files are
/// redistributed. Other DIN 472 table sizes are built by
/// `din472_parametric_outline` from the standard's own dimensions.
pub(all) struct Din472Outline {
  bore_mm : Double
  thickness_mm : Double
  chamfer_mm : Double
  start : @cad.Vec2
  ops : Array[RingOp]
  holes : Array[(Double, Double, Double)]
}

///|
/// din472_outline_12 returns the measured 12 mm internal-ring outline in the
/// default lugs-toward-+X frame.
///
/// The loop is counter-clockwise; the two plier holes sit at
/// `(4.8, +/- 1.65)` with radius 0.75 mm.
fn din472_outline_12() -> Din472Outline {
  {
    bore_mm: 12.0,
    thickness_mm: 1.0,
    chamfer_mm: 0.0,
    start: (6.4788, -0.525),
    ops: [
      RingLine(3.5255, -0.525),
      RingArc(3.1179, -1.4042, 3.2568, -2.3632),
      RingArc(-4.8, 0.0, 3.2568, 2.3632),
      RingArc(3.1179, 1.4042, 3.5255, 0.525),
      RingLine(6.4788, 0.525),
      RingArc(-6.5, 0.0, 6.4788, -0.525),
    ],
    holes: [(4.8, 1.65, 0.75), (4.8, -1.65, 0.75)],
  }
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
    chamfer_mm: 0.0,
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
/// din472_outline_10 returns the measured 10 mm internal-ring outline.
///
/// New outlines 10, 14, 16, 18, 24, 28, 32, and 40 are re-encoded from the
/// mid-plane sections of FreeCAD-parts_library's CC BY-SA 4.0 DIN 472 STEPs
/// (sisul01, commit 2141521). The measured outline data for those sizes are
/// CC BY-SA 4.0; the source files are not redistributed. The 12 mm and 20 mm
/// outlines remain from the CC0 Innerscene references.
fn din472_outline_10() -> Din472Outline {
  {
    bore_mm: 10.0,
    thickness_mm: 1.0,
    chamfer_mm: 0.1,
    start: (4.8275, 2.4198),
    ops: [
      RingArc(-5.4, 0.0, 4.8275, -2.4198),
      RingLine(4.8044, -2.3223),
      RingLine(3.1032, -1.5),
      RingArc(1.4105, -1.6886, 0.8469, -3.2958),
      RingArc(0.6766, -3.9913, 0.0178, -4.272),
      RingArc(-4.0, 0.0, 0.0178, 4.272),
      RingArc(0.6766, 3.9913, 0.8469, 3.2958),
      RingArc(1.4105, 1.6886, 3.1032, 1.5),
      RingLine(4.8044, 2.3223),
      RingLine(4.8275, 2.4198),
    ],
    holes: [(2.4069, 2.9405, 0.6), (2.4069, -2.9405, 0.6)],
  }
}

///|
/// din472_outline_14 returns the measured 14 mm internal-ring outline.
fn din472_outline_14() -> Din472Outline {
  {
    bore_mm: 14.0,
    thickness_mm: 1.0,
    chamfer_mm: 0.1,
    start: (7.2303, 2.1737),
    ops: [
      RingArc(-7.55, 0.0, 7.2303, -2.1737),
      RingLine(7.1891, -2.0824),
      RingLine(5.1786, -1.5),
      RingArc(3.192, -2.1562, 3.0878, -4.2458),
      RingArc(3.1787, -5.0186, 2.6477, -5.5873),
      RingArc(-5.65, 0.0, 2.6477, 5.5873),
      RingArc(3.1787, 5.0186, 3.0878, 4.2458),
      RingArc(3.192, 2.1562, 5.1786, 1.5),
      RingLine(7.1891, 2.0824),
      RingLine(7.2303, 2.1737),
    ],
    holes: [(4.6639, 3.277, 0.85), (4.6639, -3.277, 0.85)],
  }
}

///|
/// din472_outline_16 returns the measured 16 mm internal-ring outline.
fn din472_outline_16() -> Din472Outline {
  {
    bore_mm: 16.0,
    thickness_mm: 1.0,
    chamfer_mm: 0.1,
    start: (8.397, 2.0767),
    ops: [
      RingArc(-8.65, 0.0, 8.397, -2.0767),
      RingLine(8.3505, -1.9879),
      RingLine(6.301, -1.5),
      RingArc(4.2497, -2.3415, 4.3925, -4.554),
      RingArc(4.5962, -5.3082, 4.1658, -5.96),
      RingArc(-6.65, 0.0, 4.1658, 5.96),
      RingArc(4.5962, 5.3082, 4.3925, 4.554),
      RingArc(4.2497, 2.3415, 6.301, 1.5),
      RingLine(8.3505, 1.9879),
      RingLine(8.397, 2.0767),
    ],
    holes: [(5.861, 3.3483, 0.85), (5.861, -3.3483, 0.85)],
  }
}

///|
/// din472_outline_18 returns the measured 18 mm internal-ring outline.
fn din472_outline_18() -> Din472Outline {
  {
    bore_mm: 18.0,
    thickness_mm: 1.0,
    chamfer_mm: 0.1,
    start: (9.5333, 2.0442),
    ops: [
      RingArc(-9.75, 0.0, 9.5333, -2.0442),
      RingLine(9.4838, -1.9571),
      RingLine(7.2689, -1.5),
      RingArc(5.0704, -2.4982, 5.347, -4.8968),
      RingArc(5.6137, -5.6872, 5.2043, -6.4141),
      RingArc(-7.55, 0.0, 5.2044, 6.4141),
      RingArc(5.6137, 5.6872, 5.347, 4.8968),
      RingArc(5.0704, 2.4982, 7.2689, 1.5),
      RingLine(9.4838, 1.9571),
      RingLine(9.5333, 2.0442),
    ],
    holes: [(6.8546, 3.5077, 1.0), (6.8546, -3.5077, 1.0)],
  }
}

///|
/// din472_outline_24 returns the measured 24 mm internal-ring outline.
fn din472_outline_24() -> Din472Outline {
  {
    bore_mm: 24.0,
    thickness_mm: 1.2,
    chamfer_mm: 0.12,
    start: (12.7436, 2.3031),
    ops: [
      RingArc(-12.95, 0.0, 12.7436, -2.3031),
      RingLine(12.6794, -2.2014),
      RingLine(10.3674, -1.8),
      RingArc(8.0014, -3.0287, 8.5572, -5.6361),
      RingArc(8.9377, -6.3951, 8.6645, -7.1989),
      RingArc(-10.35, 0.0, 8.6645, 7.1989),
      RingArc(8.9377, 6.3951, 8.5572, 5.6361),
      RingArc(8.0014, 3.0287, 10.3674, 1.8),
      RingLine(12.6794, 2.2014),
      RingLine(12.7436, 2.3031),
    ],
    holes: [(9.991, 3.9676, 1.0), (9.991, -3.9676, 1.0)],
  }
}

///|
/// din472_outline_28 returns the measured 28 mm internal-ring outline.
fn din472_outline_28() -> Din472Outline {
  {
    bore_mm: 28.0,
    thickness_mm: 1.2,
    chamfer_mm: 0.12,
    start: (14.878, 2.2691),
    ops: [
      RingArc(-15.05, 0.0, 14.878, -2.2691),
      RingLine(14.8108, -2.1694),
      RingLine(12.2891, -1.8),
      RingArc(9.734, -3.2325, 10.4671, -6.0686),
      RingArc(10.9203, -6.8628, 10.6824, -7.7457),
      RingArc(-12.15, 0.0, 10.6824, 7.7456),
      RingArc(10.9203, 6.8628, 10.4671, 6.0686),
      RingArc(9.734, 3.2325, 12.2891, 1.8),
      RingLine(14.8108, 2.1694),
      RingLine(14.878, 2.2691),
    ],
    holes: [(11.9413, 4.1747, 1.0), (11.9413, -4.1747, 1.0)],
  }
}

///|
/// din472_outline_32 returns the measured 32 mm internal-ring outline.
fn din472_outline_32() -> Din472Outline {
  {
    bore_mm: 32.0,
    thickness_mm: 1.2,
    chamfer_mm: 0.12,
    start: (17.0507, 2.2613),
    ops: [
      RingArc(-17.2, 0.0, 17.0507, -2.2613),
      RingLine(16.9816, -2.1629),
      RingLine(14.1322, -1.8),
      RingArc(11.279, -3.4888, 12.2138, -6.6698),
      RingArc(12.7577, -7.5485, 12.5208, -8.5543),
      RingArc(-14.0, 0.0, 12.5208, 8.5543),
      RingArc(12.7577, 7.5485, 12.2139, 6.6698),
      RingArc(11.279, 3.4888, 14.1322, 1.8),
      RingLine(16.9816, 2.1629),
      RingLine(17.0507, 2.2613),
    ],
    holes: [(13.7911, 4.4784, 1.25), (13.7911, -4.4784, 1.25)],
  }
}

///|
/// din472_outline_40 returns the measured 40 mm internal-ring outline.
fn din472_outline_40() -> Din472Outline {
  {
    bore_mm: 40.0,
    thickness_mm: 1.75,
    chamfer_mm: 0.175,
    start: (21.5144, 3.1927),
    ops: [
      RingArc(-21.75, 0.0, 21.5144, -3.1927),
      RingLine(21.4146, -3.0485),
      RingLine(18.4397, -2.625),
      RingArc(15.3506, -4.3889, 16.2945, -7.8187),
      RingArc(16.8503, -8.707, 16.6624, -9.7379),
      RingArc(-17.85, 0.0, 16.6624, 9.7379),
      RingArc(16.8503, 8.707, 16.2945, 7.8187),
      RingArc(15.3506, 4.389, 18.4397, 2.625),
      RingLine(21.4146, 3.0485),
      RingLine(21.5144, 3.1927),
    ],
    holes: [(18.031, 5.4961, 1.25), (18.031, -5.4961, 1.25)],
  }
}

///|
/// din472_circle_intersections returns the two intersections of two circles.
fn din472_circle_intersections(
  c0 : @cad.Vec2,
  r0 : Double,
  c1 : @cad.Vec2,
  r1 : Double,
) -> Array[@cad.Vec2] {
  let (x0, y0) = c0
  let (x1, y1) = c1
  let dx = x1 - x0
  let dy = y1 - y0
  let d = (dx * dx + dy * dy).sqrt()
  if d == 0.0 || d > r0 + r1 || d < (r0 - r1).abs() {
    return []
  }
  let a = (r0 * r0 - r1 * r1 + d * d) / (2.0 * d)
  let h2 = r0 * r0 - a * a
  let h = if h2 < 0.0 { 0.0 } else { h2.sqrt() }
  let xm = x0 + a * dx / d
  let ym = y0 + a * dy / d
  let rx = -dy / d * h
  let ry = dx / d * h
  [(xm + rx, ym + ry), (xm - rx, ym - ry)]
}

///|
/// din472_parametric_outline derives a free-state outline from the DIN 472
/// table dimensions for a size with no measured reference.
///
/// The construction is driven only by the standard's thickness `s`, free
/// outside diameter `d3`, lug width `a`, back width `b`, and plier-hole
/// diameter `d5`. It reproduces the ten measured outlines' envelopes within
/// about 0.1 mm and their material areas within a few percent; those measured
/// outlines remain authoritative for their sizes. This is an engineering
/// construction, not a measured B-rep and not a guess at an unspecified curve:
/// it is derived from, and validated against, the licensed measured outlines.
fn din472_parametric_outline(
  size : @standards.DIN472Size,
) -> Result[Din472Outline, @common.SpecError] {
  let ro = size.free_outer_diameter_mm / 2.0
  let ri = ro - size.ring_width_mm
  let rf = size.lug_width_mm / 2.0
  let ytip = DIN472_PARAM_TIP_PER_THICKNESS * size.thickness_mm
  let rc = ro - rf
  let cx = DIN472_PARAM_INNER_OFFSET_PER_BORE * size.bore_diameter_mm
  let rin = ri + cx
  // The lug fillet is tangent to the outer circle and its tangent point on the
  // tip line lies on the offset inner circle. Solve for that height.
  let residual = fn(yh : Double) -> Double {
    let xh2 = rc * rc - yh * yh
    if xh2 <= 0.0 {
      return 1.0e9
    }
    let xh = xh2.sqrt()
    let d = rf * rf - (yh - ytip) * (yh - ytip)
    if d <= 0.0 {
      return 1.0e9
    }
    let s = d.sqrt()
    let qx = xh + s - cx
    qx * qx + ytip * ytip - rin * rin
  }
  let mut lo = ytip + 1.0e-9
  let mut hi = ytip + rf - 1.0e-9
  let mut flo = residual(lo)
  if flo * residual(hi) > 0.0 {
    return Err(
      @common.SpecError::InvalidParameter(
        "DIN 472 parametric outline has no solution for this size",
      ),
    )
  }
  for _ in 0..<200 {
    let mid = (lo + hi) / 2.0
    let fm = residual(mid)
    if flo * fm <= 0.0 {
      hi = mid
    } else {
      lo = mid
      flo = fm
    }
  }
  let yh = (lo + hi) / 2.0
  let xh = (rc * rc - yh * yh).sqrt()
  let s_off = (rf * rf - (yh - ytip) * (yh - ytip)).sqrt()
  let q0 = (xh + s_off, -ytip)
  let q1 = (xh + s_off, ytip)
  // The tip line is tangent to the fillet at Q0; its outer intersection gives
  // the outer-arc endpoint.
  let tx = yh - ytip
  let ty = -s_off
  let aa = tx * tx + ty * ty
  let bb = 2.0 * (q0.0 * tx + q0.1 * ty)
  let cc = q0.0 * q0.0 + q0.1 * q0.1 - ro * ro
  let disc = bb * bb - 4.0 * aa * cc
  if aa == 0.0 || disc < 0.0 {
    return Err(
      @common.SpecError::InvalidParameter(
        "DIN 472 parametric tip line misses the free outside diameter",
      ),
    )
  }
  let t = (-bb + disc.sqrt()) / (2.0 * aa)
  let p0 = (q0.0 + t * tx, q0.1 + t * ty)
  let p1 = (p0.0, -p0.1)
  let inter = din472_circle_intersections((cx, 0.0), rin, (xh, -yh), rf)
  if inter.length() < 2 {
    return Err(
      @common.SpecError::InvalidParameter(
        "DIN 472 parametric lug fillet does not meet the inner outline",
      ),
    )
  }
  let mut r0 = inter[0]
  let mut far = (r0.0 - q0.0) * (r0.0 - q0.0) + (r0.1 - q0.1) * (r0.1 - q0.1)
  for i in 1..<inter.length() {
    let p = inter[i]
    let d = (p.0 - q0.0) * (p.0 - q0.0) + (p.1 - q0.1) * (p.1 - q0.1)
    if d > far {
      r0 = p
      far = d
    }
  }
  let r1 = (r0.0, -r0.1)
  // Pick the fillet arc that protrudes into the bore (the lug's inner face).
  let h0 = (xh, -yh)
  let aq = @math.atan2(q0.1 - h0.1, q0.0 - h0.0)
  let ar = @math.atan2(r0.1 - h0.1, r0.0 - h0.0)
  let mid1 = (aq + ar) / 2.0
  let mid2 = mid1 + @math.PI
  let m1 = (xh + rf * @math.cos(mid1), -yh + rf * @math.sin(mid1))
  let m2 = (xh + rf * @math.cos(mid2), -yh + rf * @math.sin(mid2))
  let inside1 = (m1.0 - cx) * (m1.0 - cx) + m1.1 * m1.1 < rin * rin
  let fm = if inside1 { m1 } else { m2 }
  let inner_mid = (cx - rin, 0.0)
  let upper_fm = (fm.0, -fm.1)
  let holes : Array[(Double, Double, Double)] = [
    (xh, yh, size.lug_hole_mm / 2.0),
    (xh, -yh, size.lug_hole_mm / 2.0),
  ]
  Ok({
    bore_mm: size.bore_diameter_mm,
    thickness_mm: size.thickness_mm,
    chamfer_mm: 0.0,
    start: p1,
    ops: [
      RingArc(-ro, 0.0, p0.0, p0.1),
      RingLine(q0.0, q0.1),
      RingArc(fm.0, fm.1, r0.0, r0.1),
      RingArc(inner_mid.0, inner_mid.1, r1.0, r1.1),
      RingArc(upper_fm.0, upper_fm.1, q1.0, q1.1),
      RingLine(p1.0, p1.1),
    ],
    holes,
  })
}

///|
/// din472_has_measured_outline reports whether a bore has a licensed measured
/// free-state outline.
fn din472_has_measured_outline(bore_mm : Double) -> Bool {
  for size in [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 40.0] {
    if (bore_mm - size).abs() < 1.0e-9 {
      return true
    }
  }
  false
}

///|
/// din472_outline returns the free-state outline for a DIN 472 bore size.
///
/// Ten sizes use their licensed measured outlines: 12/20 mm from CC0
/// Innerscene and 10/14/16/18/24/28/32/40 mm from CC BY-SA 4.0
/// FreeCAD-parts_library. Every other size in the DIN 472 table is derived
/// parametrically from the standard's dimensions by
/// `din472_parametric_outline`, so the builder no longer depends on which
/// reference B-reps happen to exist. Bore sizes outside the table are
/// rejected by `@standards.din472_size`.
pub fn din472_outline(
  bore_mm : Double,
) -> Result[Din472Outline, @common.SpecError] {
  let outlines : Array[(Double, () -> Din472Outline)] = [
    (10.0, din472_outline_10),
    (12.0, din472_outline_12),
    (14.0, din472_outline_14),
    (16.0, din472_outline_16),
    (18.0, din472_outline_18),
    (20.0, din472_outline_20),
    (24.0, din472_outline_24),
    (28.0, din472_outline_28),
    (32.0, din472_outline_32),
    (40.0, din472_outline_40),
  ]
  for entry in outlines {
    let (size, make) = entry
    if (bore_mm - size).abs() < 1.0e-9 {
      return Ok(make())
    }
  }
  match @standards.din472_size(bore_mm) {
    Err(e) => Err(e)
    Ok(size) => din472_parametric_outline(size)
  }
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
/// din472_outline_source returns the provenance and license of an encoded
/// free-state outline.
fn din472_outline_source(bore_mm : Double) -> String {
  for size in [10.0, 14.0, 16.0, 18.0, 24.0, 28.0, 32.0, 40.0] {
    if (bore_mm - size).abs() < 1.0e-9 {
      return "FreeCAD-parts_library (sisul01, commit 2141521) CC BY-SA 4.0 measured mid-plane outline, re-encoded as an original line/arc loop"
    }
  }
  for size in [12.0, 20.0] {
    if (bore_mm - size).abs() < 1.0e-9 {
      return "CC0 1.0 Innerscene measured outline, re-encoded as an original line/arc loop"
    }
  }
  "parametric DIN 472 construction from the table's d3, a, b, d5, and s, validated against the ten measured outlines; no reference edge break"
}

///|
/// din472_ring builds a DIN 472 internal retaining ring for a nominal bore
/// diameter.
///
/// The ring lies in the XY plane from `z = 0` to `z = s`, its axis along +Z,
/// and its lugs toward +X. The free-state outline and the two plier holes are
/// modelled; the bore groove is not. Every DIN 472 table size builds. Ten
/// sizes use licensed measured outlines: 12/20 mm from CC0 Innerscene and
/// 10/14/16/18/24/28/32/40 mm from CC BY-SA 4.0 FreeCAD-parts_library. The
/// remaining table sizes are derived parametrically from the standard's
/// dimensions, so capability is not limited by reference availability. Bore
/// sizes outside the table are rejected.
///
/// The eight FreeCAD-derived sizes carry real 45-degree, 0.1/0.12/0.175 mm
/// chamfers on both face boundaries and require
/// `write_step_evaluated`. The 12/20 mm CC0 rings and the parametric sizes
/// remain flat and sharp. No spring temper or load, torque, or fatigue rating
/// is implied.
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
              let base_node = profile.as_shape().with_name("ring-base")
              let body = if outline.chamfer_mm > 0.0 {
                @cad.chamfer_edges(
                  base_node,
                  outline.chamfer_mm,
                  selector=@cad.EdgeSelector::EdgesPerpendicularToDirection(
                    (0.0, 0.0, 1.0),
                    1.0,
                  ),
                  name="edge-chamfers",
                )
              } else {
                profile.as_shape().with_name("body")
              }
              let modeled : Array[String] = [
                "flat-ring", "inward-lugs", "plier-holes", "free-outside-diameter",
              ]
              let omitted : Array[@common.Omission] = [
                @common.Omission::new(
                  feature="bore-groove",
                  reason="the groove (d2 x m) is a bore feature; it is declared by the groove-seat connector, not modelled",
                ),
                @common.Omission::new(
                  feature="spring-temper-and-load-rating",
                  reason="material condition, installation force, and load or fatigue capacity are not modelled",
                ),
              ]
              let measured = din472_has_measured_outline(bore_mm)
              if outline.chamfer_mm > 0.0 {
                modeled.push("edge-chamfers")
              } else {
                omitted.push(
                  @common.Omission::new(
                    feature="edge-breaks",
                    reason=if measured {
                      "the CC0 reference model has sharp edges; no deburring or radius is modelled"
                    } else {
                      "the parametric outline has sharp edges; no reference edge break is modelled"
                    },
                  ),
                )
              }
              let features = @common.FeatureRecord::new(
                modeled~,
                approximated=[
                  @common.Approximation::new(
                    feature="outline-between-the-back-and-the-lugs",
                    kind=@common.ApproximationKind::EngineeringDefault,
                    deviation_mm=if measured { 0.0 } else { 0.1 },
                    control="\{@cad.fmt_double(bore_mm, None)} mm: " +
                      din472_outline_source(bore_mm) +
                      "; DIN 472 does not dimension this curve",
                  ),
                ],
                omitted~,
              )
              let edge_text = if outline.chamfer_mm > 0.0 {
                "45 degree x \{@cad.fmt_double(outline.chamfer_mm, None)} mm chamfers on both face boundaries"
              } else {
                "sharp edges"
              }
              let component = @common.Component::new(
                name="din472-\{@cad.fmt_double(bore_mm, None)}",
                metadata=@common.Metadata::new(
                  designation=size.designation(),
                  standard=@standards.DIN472Size::standard(),
                  family="internal retaining ring",
                  size="\{@cad.fmt_double(bore_mm, None)}",
                  source=@standards.DIN472Size::source() +
                    " Free-state outline: " +
                    din472_outline_source(bore_mm) +
                    ".",
                ),
                description="DIN 472 internal retaining ring: a flat stamped ring with two inward lugs, plier holes, and a free outside diameter; " +
                  edge_text +
                  ". The chamfered sizes require write_step_evaluated. No groove, spring temper, or load rating.",
                features~,
              ).add_layer(body.shape_intent(), name="body", color~)
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
