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

///|
/// obround_loop returns a counter-clockwise obround (stadium) hole loop: two
/// semicircular end caps of `radius` whose centres are `half_cap_distance`
/// either side of `(cx, cy)` along the unit direction `(dir_x, dir_y)`.
///
/// The long axis is exactly `(dir_x, dir_y)`, so callers can build slots along
/// X, Y, a diagonal, or any measured angle without recomputing tangency.
pub fn obround_loop(
  cx : Double,
  cy : Double,
  dir_x : Double,
  dir_y : Double,
  half_cap_distance : Double,
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let len = (dir_x * dir_x + dir_y * dir_y).sqrt()
  let dx = if len > 0.0 { dir_x / len } else { 1.0 }
  let dy = if len > 0.0 { dir_y / len } else { 0.0 }
  let nx = -dy
  let ny = dx
  let left = (cx - dx * half_cap_distance, cy - dy * half_cap_distance)
  let right = (cx + dx * half_cap_distance, cy + dy * half_cap_distance)
  let low_left = (left.0 - nx * radius, left.1 - ny * radius)
  let high_left = (left.0 + nx * radius, left.1 + ny * radius)
  let low_right = (right.0 - nx * radius, right.1 - ny * radius)
  let high_right = (right.0 + nx * radius, right.1 + ny * radius)
  [
    @cad.SegmentLine(low_left, low_right),
    @cad.SegmentArc(low_right, high_right, right),
    @cad.SegmentLine(high_right, high_left),
    @cad.SegmentArc(high_left, low_left, left),
  ]
}

///|
/// disc_pair_loop returns the counter-clockwise boundary of the union of two
/// equal circles that overlap. It is the exact hole loop for a pair of
/// near-coincident bores, which a plain circle loop cannot represent without
/// self-intersection.
///
/// Each circle contributes a major arc; each major arc is split into two minor
/// arcs at the point farthest from the other centre, so every segment stays a
/// valid counter-clockwise minor arc. Circles that do not overlap fall back to
/// a single circle.
pub fn disc_pair_loop(
  c1 : (Double, Double),
  c2 : (Double, Double),
  radius : Double,
) -> Array[@cad.ProfileSegment] {
  let vx = c2.0 - c1.0
  let vy = c2.1 - c1.1
  let d = (vx * vx + vy * vy).sqrt()
  if d <= 1.0e-12 || d >= 2.0 * radius - 1.0e-12 {
    return circle_loop(c1.0, c1.1, radius)
  }
  let ux = vx / d
  let uy = vy / d
  let nx = -uy
  let ny = ux
  let mid = (0.5 * (c1.0 + c2.0), 0.5 * (c1.1 + c2.1))
  let h = (radius * radius - 0.25 * d * d).sqrt()
  let p1 = (mid.0 + nx * h, mid.1 + ny * h)
  let p2 = (mid.0 - nx * h, mid.1 - ny * h)
  let q1 = (c1.0 - ux * radius, c1.1 - uy * radius)
  let q2 = (c2.0 + ux * radius, c2.1 + uy * radius)
  [
    @cad.SegmentArc(p1, q1, c1),
    @cad.SegmentArc(q1, p2, c1),
    @cad.SegmentArc(p2, q2, c2),
    @cad.SegmentArc(q2, p1, c2),
  ]
}

///|
/// translate_loops offsets every point of every loop by `(dx, dy)`.
pub fn translate_loops(
  loops : Array[Array[@cad.ProfileSegment]],
  dx : Double,
  dy : Double,
) -> Array[Array[@cad.ProfileSegment]] {
  loops.map(fn(segments) {
    segments.map(fn(seg) {
      match seg {
        @cad.SegmentLine(a, b) =>
          @cad.SegmentLine((a.0 + dx, a.1 + dy), (b.0 + dx, b.1 + dy))
        @cad.SegmentArc(a, b, c) =>
          @cad.SegmentArc(
            (a.0 + dx, a.1 + dy),
            (b.0 + dx, b.1 + dy),
            (c.0 + dx, c.1 + dy),
          )
      }
    })
  })
}
