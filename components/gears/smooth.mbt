///|
// Smooth extruded profiles for gear outlines.
//
// The gear builders otherwise emit their involute/tip/root outlines as
// polylines, which becomes one planar facet per segment (hundreds of planes per
// gear). These helpers convert the sampled outline into a cubic Bezier path and
// extrude it with `ExtrudedBezierProfile`, whose STEP compiler emits one closed
// cubic B-spline curve per contour and one `SURFACE_OF_LINEAR_EXTRUSION`
// lateral face: a single smooth extrusion per gear, with no planar facets.

///|
/// SMOOTH_INVOLUTE_POINTS is the per-flank sample count for a smooth gear
/// outline.
pub const SMOOTH_INVOLUTE_POINTS : Int32 = 4

///|
/// SMOOTH_ARC_POINTS is the per-arc sample count for a smooth gear outline.
pub const SMOOTH_ARC_POINTS : Int32 = 2

///|
/// smooth_outline_path converts a closed polyline into a cubic Bezier path with
/// Catmull-Rom (cardinal) handles. The curve passes through every sampled
/// involute/tip/root point, so the flanks are smooth.
pub fn smooth_outline_path(
  outline : Array[@cad.Vec2],
  clear~ : Bool = false,
) -> @cad.BezierPath {
  let n = outline.length()
  let anchors : Array[@cad.BezierAnchor] = []
  let k = 1.0 / 6.0
  for i in 0..<n {
    let p = outline[i]
    let prev = outline[(i + n - 1) % n]
    let next = outline[(i + 1) % n]
    let tx = k * (next.0 - prev.0)
    let ty = k * (next.1 - prev.1)
    anchors.push(
      @cad.BezierAnchor::new(p, (p.0 - tx, p.1 - ty), (p.0 + tx, p.1 + ty)),
    )
  }
  @cad.BezierPath::new(anchors, closed=true, clear~)
}

///|
/// bezier_circle_path builds a circle as four cubic Bezier spans (the standard
/// 0.5522847498 control-handle factor). It is used for circular boundaries and
/// central bores.
pub fn bezier_circle_path(
  diameter : Double,
  clear~ : Bool = false,
) -> @cad.BezierPath {
  let r = diameter / 2.0
  let k = 0.5522847498307936 * r
  @cad.BezierPath::new(
    [
      @cad.BezierAnchor::new((r, 0.0), (r, -k), (r, k)),
      @cad.BezierAnchor::new((0.0, r), (k, r), (-k, r)),
      @cad.BezierAnchor::new((-r, 0.0), (-r, k), (-r, -k)),
      @cad.BezierAnchor::new((0.0, -r), (-k, -r), (k, -r)),
    ],
    closed=true,
    clear~,
  )
}
