///|
/// Shared 2D profile geometry for parametric components.
///
/// These primitives were reimplemented in several subpackages (motors,
/// makerpipe, pvc, ...). Keep one definition here so a change to the 4-arc
/// circle cannot drift between packages: these arcs are the repo's main hole
/// primitive, and drift here silently changes STEP topology.

///|
/// polar_deg converts a radius and an angle in degrees to an XY point.
pub fn polar_deg(radius : Double, angle_deg : Double) -> (Double, Double) {
  let angle = angle_deg * @math.PI / 180.0
  (radius * @math.cos(angle), radius * @math.sin(angle))
}

///|
/// circle_loop returns a counter-clockwise full circle as four minor arcs.
pub fn circle_loop(
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let c = (cx, cy)
  [
    @cad.SegmentArc((cx + radius, cy), (cx, cy + radius), c),
    @cad.SegmentArc((cx, cy + radius), (cx - radius, cy), c),
    @cad.SegmentArc((cx - radius, cy), (cx, cy - radius), c),
    @cad.SegmentArc((cx, cy - radius), (cx + radius, cy), c),
  ]
}
