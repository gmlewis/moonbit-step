///|
// Exact line-plus-arc extrusion for gear outlines.
//
// The faceted gear builders extrude a polyline, which becomes one planar facet
// per segment (hundreds of planes per gear). These helpers keep the sampled
// outline's exact geometry but split it at its sharp corners and fit one minor
// arc through each smooth run, then extrude with `ExtrudedArcProfile`. Each
// tooth flank/root run becomes a single `CYLINDRICAL_SURFACE`, so the gear is
// one extrusion of its top face with a few wide, smooth side faces per tooth —
// no polyline facets and no spline distortion of straight/arc segments.

///|
/// SMOOTH_INVOLUTE_POINTS is the per-flank sample count used to build the
/// outline that the arc runs are fitted to.
pub const SMOOTH_INVOLUTE_POINTS : Int32 = 4

///|
/// SMOOTH_ARC_POINTS is the per-arc sample count for the outline.
pub const SMOOTH_ARC_POINTS : Int32 = 2

///|
/// arc_center_xy returns the circumcentre of three points, or None when they
/// are collinear (the caller then emits a line).
fn arc_center_xy(a : @cad.Vec2, b : @cad.Vec2, c : @cad.Vec2) -> @cad.Vec2? {
  let d = 2.0 * (a.0 * (b.1 - c.1) + b.0 * (c.1 - a.1) + c.0 * (a.1 - b.1))
  if d.abs() < 1.0e-12 {
    None
  } else {
    let aa = a.0 * a.0 + a.1 * a.1
    let bb = b.0 * b.0 + b.1 * b.1
    let cc = c.0 * c.0 + c.1 * c.1
    Some(
      (
        (aa * (b.1 - c.1) + bb * (c.1 - a.1) + cc * (a.1 - b.1)) / d,
        (aa * (c.0 - b.0) + bb * (a.0 - c.0) + cc * (b.0 - a.0)) / d,
      ),
    )
  }
}

///|
/// arc_outline_runs splits a closed outline at its sharp corners (tooth tips
/// and root junctions) and fits one minor arc through each smooth run between
/// them, producing a closed counter-clockwise line-plus-arc loop that follows
/// the sampled geometry exactly.
pub fn arc_outline_runs(
  outline : Array[@cad.Vec2],
) -> Array[@cad.ProfileSegment] {
  let n = outline.length()
  let pts = if @cad.polygon_area_2d(outline) < 0.0 {
    outline.rev()
  } else {
    outline
  }
  let corner_cos = @math.cos(25.0 * @math.PI / 180.0)
  let corners : Array[Int32] = []
  for k in 0..<n {
    let p = pts[k]
    let a = pts[(k + n - 1) % n]
    let b = pts[(k + 1) % n]
    let ax = p.0 - a.0
    let ay = p.1 - a.1
    let bx = b.0 - p.0
    let by = b.1 - p.1
    let alen = Double::sqrt(ax * ax + ay * ay)
    let blen = Double::sqrt(bx * bx + by * by)
    let sharp = if alen < 1.0e-12 || blen < 1.0e-12 {
      true
    } else {
      (ax * bx + ay * by) / (alen * blen) < corner_cos
    }
    if sharp {
      corners.push(k)
    }
  }
  if corners.length() < 2 {
    return arc_outline_segments(outline)
  }
  let segments : Array[@cad.ProfileSegment] = []
  let c = corners.length()
  for j in 0..<c {
    let i0 = corners[j]
    let i1 = corners[(j + 1) % c]
    let run_len = if i1 > i0 { i1 - i0 } else { n - i0 + i1 }
    let im = (i0 + run_len / 2) % n
    let a = pts[i0]
    let b = pts[i1]
    let m = pts[im]
    if run_len <= 1 {
      segments.push(@cad.SegmentLine(a, b))
    } else {
      match arc_center_xy(a, m, b) {
        Some(center) => segments.push(@cad.SegmentArc(a, b, center))
        None => segments.push(@cad.SegmentLine(a, b))
      }
    }
  }
  segments
}

///|
/// arc_outline_segments converts a closed polyline into a closed
/// counter-clockwise loop of minor arcs (one per edge), used when the outline
/// has no detectable corners.
pub fn arc_outline_segments(
  outline : Array[@cad.Vec2],
) -> Array[@cad.ProfileSegment] {
  let n = outline.length()
  let pts = if @cad.polygon_area_2d(outline) < 0.0 {
    outline.rev()
  } else {
    outline
  }
  let segments : Array[@cad.ProfileSegment] = []
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    let c = pts[(i + 2) % n]
    match arc_center_xy(a, b, c) {
      Some(center) => segments.push(@cad.SegmentArc(a, b, center))
      None => segments.push(@cad.SegmentLine(a, b))
    }
  }
  segments
}

///|
/// arc_circle_segments builds a circle as four concentric quarter arcs.
pub fn arc_circle_segments(diameter : Double) -> Array[@cad.ProfileSegment] {
  let r = diameter / 2.0
  let p0 : @cad.Vec2 = (r, 0.0)
  let p1 : @cad.Vec2 = (0.0, r)
  let p2 : @cad.Vec2 = (-r, 0.0)
  let p3 : @cad.Vec2 = (0.0, -r)
  let center : @cad.Vec2 = (0.0, 0.0)
  [
    @cad.SegmentArc(p0, p1, center),
    @cad.SegmentArc(p1, p2, center),
    @cad.SegmentArc(p2, p3, center),
    @cad.SegmentArc(p3, p0, center),
  ]
}
