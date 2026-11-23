///|
/// circle_pt returns a point on a circle in the profile plane.
fn circle_pt(radius : Double, angle_rad : Double) -> @cad.Vec2 {
  (radius * @math.cos(angle_rad), radius * @math.sin(angle_rad))
}

///|
/// push_arc appends the circular arc from `a0` to `a1`, splitting a sweep
/// larger than pi into two minor arcs because `SegmentArc` uses the signed
/// minor sweep.
fn push_arc(
  segments : Array[@cad.ProfileSegment],
  radius : Double,
  a0 : Double,
  a1 : Double,
) -> Unit {
  let sweep = a1 - a0
  if sweep.abs() < @step.TOL_1E9 {
    return
  }
  if sweep.abs() <= @math.PI + @step.TOL_1E9 {
    segments.push(
      @cad.SegmentArc(circle_pt(radius, a0), circle_pt(radius, a1), (0.0, 0.0)),
    )
  } else {
    let mid = (a0 + a1) / 2.0
    segments.push(
      @cad.SegmentArc(circle_pt(radius, a0), circle_pt(radius, mid), (0.0, 0.0)),
    )
    segments.push(
      @cad.SegmentArc(circle_pt(radius, mid), circle_pt(radius, a1), (0.0, 0.0)),
    )
  }
}

///|
/// annular_sector_loop builds a CCW annular sector between two radii and two
/// angles. The sweep is `end - start`; split large sweeps with `push_arc`.
fn annular_sector_loop(
  inner_radius : Double,
  outer_radius : Double,
  start_rad : Double,
  end_rad : Double,
) -> Array[@cad.ProfileSegment] {
  let segments : Array[@cad.ProfileSegment] = []
  push_arc(segments, outer_radius, start_rad, end_rad)
  segments.push(
    @cad.SegmentLine(
      circle_pt(outer_radius, end_rad),
      circle_pt(inner_radius, end_rad),
    ),
  )
  push_arc(segments, inner_radius, end_rad, start_rad)
  segments.push(
    @cad.SegmentLine(
      circle_pt(inner_radius, start_rad),
      circle_pt(outer_radius, start_rad),
    ),
  )
  segments
}

///|
/// opening_half_angle returns the angular half-width of a socket opening in a
/// clamp ring, from the bore radius and the ring outside radius.
fn opening_half_angle(bore_radius : Double, outer_radius : Double) -> Double {
  if outer_radius <= 0.0 || bore_radius >= outer_radius {
    @math.PI / 2.0
  } else {
    @math.asin(bore_radius / outer_radius)
  }
}

///|
/// normalize_angle returns an angle in `[0, 2*pi)`.
fn normalize_angle(angle_rad : Double) -> Double {
  let two_pi = 2.0 * @math.PI
  let mut a = angle_rad
  while a < 0.0 {
    a = a + two_pi
  }
  while a >= two_pi {
    a = a - two_pi
  }
  a
}

///|
/// branch_material_intervals returns the annular-sector spans left between
/// circular branch openings.
///
/// Each branch angle is expanded to an opening of `+/- phi`; the intervals
/// between consecutive openings are the saddle material. Intervals that close
/// on themselves are omitted (for example the 5-way, where four openings cover
/// the whole ring).
fn branch_material_intervals(
  angles_rad : Array[Double],
  phi : Double,
) -> Array[(Double, Double)] {
  let sorted = angles_rad.copy()
  sorted.sort_by(fn(a, b) { a.compare(b) })
  let out : Array[(Double, Double)] = []
  let n = sorted.length()
  if n == 0 {
    return out
  }
  let two_pi = 2.0 * @math.PI
  for i in 0..<n {
    let start = sorted[i] + phi
    let next = if i == n - 1 { sorted[0] + two_pi } else { sorted[i + 1] }
    let end = next - phi
    if end - start > @step.TOL_1E6 {
      out.push((start, end))
    }
  }
  out
}

///|
/// largest_interval_midpoint returns the midpoint angle of the widest material
/// interval, used for a nominal cross-bolt mate. When there is no material
/// (the 5-way), it returns 45 degrees so the connector still has a bolt frame.
fn largest_interval_midpoint(intervals : Array[(Double, Double)]) -> Double {
  let mut best = 45.0 * @math.PI / 180.0
  let mut best_width = -1.0
  for interval in intervals {
    let (start, end) = interval
    let width = end - start
    if width > best_width {
      best_width = width
      best = (start + end) / 2.0
    }
  }
  best
}
