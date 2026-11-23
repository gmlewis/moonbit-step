///|
/// Plane names the 2D plane a sketch is drawn in before extrusion.
pub(all) enum Plane {
  /// Sketch X is world +X and sketch Y is world +Y; extrudes along +Z.
  XY
  /// Sketch X is world +X and sketch Y is world +Z; extrudes along -Y.
  XZ
  /// Sketch X is world -Z and sketch Y is world +Y; extrudes along +X.
  YZ
}

///|
/// An immutable 2D sketch: one outer loop plus any number of hole loops.
///
/// Coordinates are millimetres in the sketch plane, centered on the sketch
/// origin. The extrusion writer normalizes the winding (outer counter-clockwise,
/// holes clockwise), so callers never need to track it.
pub(all) struct Sketch2D {
  outer : Array[Vec2]
  holes : Array[Array[Vec2]]
}

///|
const SKETCH_WHEEL_SEGS : Int32 = 72

///|
const SKETCH_SPOKE_SEGS : Int32 = 12

///|
const SKETCH_FILLET_SEGS : Int32 = 6

///|
fn sk_sub(a : Vec2, b : Vec2) -> Vec2 {
  (a.0 - b.0, a.1 - b.1)
}

///|
fn sk_dot(a : Vec2, b : Vec2) -> Double {
  a.0 * b.0 + a.1 * b.1
}

///|
fn sk_cross(a : Vec2, b : Vec2) -> Double {
  a.0 * b.1 - a.1 * b.0
}

///|
fn sk_len(a : Vec2) -> Double {
  (a.0 * a.0 + a.1 * a.1).sqrt()
}

///|
fn sk_norm(a : Vec2) -> Vec2 {
  let l = sk_len(a)
  if l < @step.TOL_1E12 {
    (0.0, 0.0)
  } else {
    (a.0 / l, a.1 / l)
  }
}

///|
fn sk_circle_points(
  cx : Double,
  cy : Double,
  r : Double,
  segs : Int32,
) -> Array[Vec2] {
  let n = if segs < 3 { 3 } else { segs }
  let out : Array[Vec2] = []
  for i in 0..<n {
    let a = 2.0 * @math.PI * i.to_double() / n.to_double()
    out.push((cx + r * @math.cos(a), cy + r * @math.sin(a)))
  }
  out
}

///|
fn sk_arc_points(
  cx : Double,
  cy : Double,
  r : Double,
  a0 : Double,
  a1 : Double,
  segs : Int32,
  include_start~ : Bool,
  include_end~ : Bool,
) -> Array[Vec2] {
  let n = if segs < 1 { 1 } else { segs }
  let start = if include_start { 0 } else { 1 }
  let end = if include_end { n } else { n - 1 }
  let out : Array[Vec2] = []
  if end < start {
    return out
  }
  for i in start..<=end {
    let t = i.to_double() / n.to_double()
    let a = a0 + (a1 - a0) * t
    out.push((cx + r * @math.cos(a), cy + r * @math.sin(a)))
  }
  out
}

///|
fn sk_ensure_ccw(pts : Array[Vec2]) -> Array[Vec2] {
  if polygon_area_2d(pts) < 0.0 {
    pts.rev()
  } else {
    pts
  }
}

///|
fn sk_transform_pts(
  pts : Array[Vec2],
  dx : Double,
  dy : Double,
  angle_deg : Double,
) -> Array[Vec2] {
  let rad = angle_deg * @math.PI / 180.0
  let c = @math.cos(rad)
  let s = @math.sin(rad)
  pts.map(fn(p) {
    let x = p.0 * c - p.1 * s + dx
    let y = p.0 * s + p.1 * c + dy
    (x, y)
  })
}

///|
fn sk_point_compare(a : Vec2, b : Vec2) -> Int32 {
  if a.0 < b.0 {
    -1
  } else if a.0 > b.0 {
    1
  } else if a.1 < b.1 {
    -1
  } else if a.1 > b.1 {
    1
  } else {
    0
  }
}

///|
/// Convex hull of a point set (monotone chain), returned counter-clockwise.
fn sk_convex_hull(points : Array[Vec2]) -> Array[Vec2] {
  let sorted = points.copy()
  sorted.sort_by(sk_point_compare)
  let unique : Array[Vec2] = []
  for p in sorted {
    if unique.length() == 0 || unique[unique.length() - 1] != p {
      unique.push(p)
    }
  }
  if unique.length() <= 2 {
    return unique
  }
  let lower : Array[Vec2] = []
  for p in unique {
    while lower.length() >= 2 &&
          sk_cross(
            sk_sub(lower[lower.length() - 1], lower[lower.length() - 2]),
            sk_sub(p, lower[lower.length() - 1]),
          ) <=
          0.0 {
      let _ = lower.pop()
    }
    lower.push(p)
  }
  let upper : Array[Vec2] = []
  for i in 0..<unique.length() {
    let p = unique[unique.length() - 1 - i]
    while upper.length() >= 2 &&
          sk_cross(
            sk_sub(upper[upper.length() - 1], upper[upper.length() - 2]),
            sk_sub(p, upper[upper.length() - 1]),
          ) <=
          0.0 {
      let _ = upper.pop()
    }
    upper.push(p)
  }
  let _ = lower.pop()
  let _ = upper.pop()
  for p in upper {
    lower.push(p)
  }
  lower
}

///|
fn sk_point_segment_distance(p : Vec2, a : Vec2, b : Vec2) -> Double {
  let ab = sk_sub(b, a)
  let len2 = sk_dot(ab, ab)
  if len2 < @step.TOL_1E18 {
    return sk_len(sk_sub(p, a))
  }
  let t = sk_dot(sk_sub(p, a), ab) / len2
  let tc = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
  let proj = (a.0 + ab.0 * tc, a.1 + ab.1 * tc)
  sk_len(sk_sub(p, proj))
}

///|
fn sk_point_in_polygon(p : Vec2, poly : Array[Vec2]) -> Bool {
  let n = poly.length()
  if n < 3 {
    return false
  }
  let mut inside = false
  let mut j = n - 1
  for i in 0..<n {
    let a = poly[i]
    let b = poly[j]
    if (a.1 > p.1) != (b.1 > p.1) &&
      p.0 < (b.0 - a.0) * (p.1 - a.1) / (b.1 - a.1) + a.0 {
      inside = !inside
    }
    j = i
  }
  inside
}

///|
/// Creates a sketch from an explicit outer loop.
pub fn Sketch2D::polygon(pts : Array[Vec2]) -> Sketch2D {
  { outer: pts, holes: [], }
}

///|
/// A width by height rectangle centered on the origin.
pub fn Sketch2D::rect(w : Double, h : Double) -> Sketch2D {
  let hw = w / 2.0
  let hh = h / 2.0
  { outer: [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)], holes: [], }
}

///|
/// A rectangle with quarter-circle fillets of radius `r` at every corner.
pub fn Sketch2D::rounded_rect(
  w : Double,
  h : Double,
  r : Double,
  arc_segs~ : Int32 = 8,
) -> Sketch2D {
  let hw = w / 2.0
  let hh = h / 2.0
  let half_min = if hw < hh { hw } else { hh }
  let rr = if r < 0.0 { 0.0 } else if r > half_min { half_min } else { r }
  if rr < CAD_LENGTH_EPS {
    return Sketch2D::rect(w, h)
  }
  let n = if arc_segs < 2 { 2 } else { arc_segs }
  let out : Array[Vec2] = []
  out.push((-hw + rr, -hh))
  out.push((hw - rr, -hh))
  for
    p in sk_arc_points(
      hw - rr,
      -hh + rr,
      rr,
      -@math.PI / 2.0,
      0.0,
      n,
      include_start=false,
      include_end=true,
    ) {
    out.push(p)
  }
  out.push((hw, hh - rr))
  for
    p in sk_arc_points(
      hw - rr,
      hh - rr,
      rr,
      0.0,
      @math.PI / 2.0,
      n,
      include_start=false,
      include_end=true,
    ) {
    out.push(p)
  }
  out.push((-hw + rr, hh))
  for
    p in sk_arc_points(
      -hw + rr,
      hh - rr,
      rr,
      @math.PI / 2.0,
      @math.PI,
      n,
      include_start=false,
      include_end=true,
    ) {
    out.push(p)
  }
  out.push((-hw, -hh + rr))
  for
    p in sk_arc_points(
      -hw + rr,
      -hh + rr,
      rr,
      @math.PI,
      1.5 * @math.PI,
      n,
      include_start=false,
      include_end=false,
    ) {
    out.push(p)
  }
  { outer: sk_ensure_ccw(out), holes: [], }
}

///|
/// A circle centered on the origin.
pub fn Sketch2D::circle(r : Double, segs~ : Int32 = 48) -> Sketch2D {
  { outer: sk_circle_points(0.0, 0.0, r, segs), holes: [], }
}

///|
/// A parallel-sided slot of overall `length` and `width`, centered on the
/// origin and running along X.
pub fn Sketch2D::slot(
  length : Double,
  width : Double,
  segs~ : Int32 = 16,
) -> Sketch2D {
  let r = width / 2.0
  let half = if length > width { (length - width) / 2.0 } else { 0.0 }
  Sketch2D::stadium_link((-half, 0.0), (half, 0.0), r, r, segs~)
}

///|
/// A link between two circular ends: the convex hull of the two circles.
pub fn Sketch2D::stadium_link(
  p0 : Vec2,
  p1 : Vec2,
  r0 : Double,
  r1 : Double,
  segs~ : Int32 = 16,
) -> Sketch2D {
  let n = if segs < 4 { 4 } else { segs }
  let points : Array[Vec2] = []
  for p in sk_circle_points(p0.0, p0.1, r0, n) {
    points.push(p)
  }
  for p in sk_circle_points(p1.0, p1.1, r1, n) {
    points.push(p)
  }
  { outer: sk_ensure_ccw(sk_convex_hull(points)), holes: [], }
}

///|
/// A curved link whose centerline bows by `arch_mm` from the straight chord.
/// Radii `r0` and `r1` set the width at each end.
pub fn Sketch2D::link_arc(
  p0 : Vec2,
  p1 : Vec2,
  r0 : Double,
  r1 : Double,
  arch_mm : Double,
  segs~ : Int32 = 16,
) -> Sketch2D {
  let d = sk_sub(p1, p0)
  let len = sk_len(d)
  if len < @step.TOL_1E6 {
    let r = if r0 > r1 { r0 } else { r1 }
    return Sketch2D::circle(r, segs~)
  }
  let n = if segs < 4 { 4 } else { segs }
  let u = sk_norm(d)
  let normal = (-u.1, u.0)
  let mid = ((p0.0 + p1.0) / 2.0, (p0.1 + p1.1) / 2.0)
  let control = (
    mid.0 + normal.0 * 2.0 * arch_mm,
    mid.1 + normal.1 * 2.0 * arch_mm,
  )
  let left : Array[Vec2] = []
  let right : Array[Vec2] = []
  let mut tan0 : Vec2 = (1.0, 0.0)
  let mut tan1 : Vec2 = (1.0, 0.0)
  for i in 0..<=n {
    let t = i.to_double() / n.to_double()
    let mt = 1.0 - t
    let bx = mt * mt * p0.0 + 2.0 * mt * t * control.0 + t * t * p1.0
    let by = mt * mt * p0.1 + 2.0 * mt * t * control.1 + t * t * p1.1
    let tx = 2.0 * mt * (control.0 - p0.0) + 2.0 * t * (p1.0 - control.0)
    let ty = 2.0 * mt * (control.1 - p0.1) + 2.0 * t * (p1.1 - control.1)
    let tan = sk_norm((tx, ty))
    if i == 0 {
      tan0 = tan
    }
    if i == n {
      tan1 = tan
    }
    let perp = (-tan.1, tan.0)
    let radius = r0 + (r1 - r0) * t
    left.push((bx + perp.0 * radius, by + perp.1 * radius))
    right.push((bx - perp.0 * radius, by - perp.1 * radius))
  }
  let cap_segs = if n / 2 < 6 { 6 } else { n / 2 }
  let loop_pts : Array[Vec2] = []
  for p in left {
    loop_pts.push(p)
  }
  // Rounded semicircular boss around p1 (sweeping outward through +tan1)
  let a1_start = @math.atan2(tan1.0, -tan1.1)
  for k in 1..<cap_segs {
    let a = a1_start - @math.PI * k.to_double() / cap_segs.to_double()
    loop_pts.push((p1.0 + r1 * @math.cos(a), p1.1 + r1 * @math.sin(a)))
  }
  for i in 0..<right.length() {
    loop_pts.push(right[right.length() - 1 - i])
  }
  // Rounded semicircular boss around p0 (sweeping outward through -tan0)
  let a0_start = @math.atan2(-tan0.0, tan0.1)
  for k in 1..<cap_segs {
    let a = a0_start - @math.PI * k.to_double() / cap_segs.to_double()
    loop_pts.push((p0.0 + r0 * @math.cos(a), p0.1 + r0 * @math.sin(a)))
  }
  { outer: sk_ensure_ccw(loop_pts), holes: [], }
}

///|
/// A spoked wheel: an outer rim with `num_spokes` spokes and the gaps between
/// them as holes. `rim_t` is the rim thickness and `hub_r` the solid hub radius.
pub fn Sketch2D::spoked_wheel(
  outer_r : Double,
  hub_r : Double,
  rim_t : Double,
  num_spokes : Int32,
  spoke_w : Double,
) -> Sketch2D {
  let outer = sk_circle_points(0.0, 0.0, outer_r, SKETCH_WHEEL_SEGS)
  let n = if num_spokes < 2 { 2 } else { num_spokes }
  let inner = if hub_r > 0.5 { hub_r } else { 0.5 }
  let rim_inner = outer_r - rim_t
  if rim_inner <= inner + 0.5 {
    return { outer: sk_ensure_ccw(outer), holes: [], }
  }
  let mid = (inner + rim_inner) / 2.0
  let spoke_angle = if mid > @step.TOL_1E6 { spoke_w / mid } else { 0.0 }
  let pitch = 2.0 * @math.PI / n.to_double()
  let mut gap = pitch - spoke_angle
  if gap < 0.05 {
    gap = 0.05
  } else if gap > pitch * 0.9 {
    gap = pitch * 0.9
  }
  let holes : Array[Array[Vec2]] = []
  for i in 0..<n {
    let center = (i.to_double() + 0.5) * pitch
    let a0 = center - gap / 2.0
    let a1 = center + gap / 2.0
    let hole : Array[Vec2] = []
    for
      p in sk_arc_points(
        0.0,
        0.0,
        inner,
        a0,
        a1,
        SKETCH_SPOKE_SEGS,
        include_start=true,
        include_end=true,
      ) {
      hole.push(p)
    }
    for
      p in sk_arc_points(
        0.0,
        0.0,
        rim_inner,
        a1,
        a0,
        SKETCH_SPOKE_SEGS,
        include_start=false,
        include_end=true,
      ) {
      hole.push(p)
    }
    holes.push(hole)
  }
  { outer: sk_ensure_ccw(outer), holes, }
}

///|
/// Adds a circular hole of diameter `diam` centered at `(cx, cy)`.
pub fn Sketch2D::with_hole_circle(
  self : Sketch2D,
  cx : Double,
  cy : Double,
  diam~ : Double,
  segs~ : Int32 = 32,
) -> Sketch2D {
  let holes = self.holes.copy()
  holes.push(sk_circle_points(cx, cy, diam / 2.0, segs))
  { ..self, holes, }
}

///|
/// Adds `count` holes evenly spaced on a bolt circle of diameter `bcd`.
pub fn Sketch2D::with_bolt_circle(
  self : Sketch2D,
  cx : Double,
  cy : Double,
  count~ : Int32,
  bcd~ : Double,
  hole_diam~ : Double,
  start_deg~ : Double = 0.0,
  segs~ : Int32 = 24,
) -> Sketch2D {
  let holes = self.holes.copy()
  let n = if count < 1 { 1 } else { count }
  for i in 0..<n {
    let a = (start_deg + 360.0 * i.to_double() / n.to_double()) *
      @math.PI /
      180.0
    let hx = cx + bcd / 2.0 * @math.cos(a)
    let hy = cy + bcd / 2.0 * @math.sin(a)
    holes.push(sk_circle_points(hx, hy, hole_diam / 2.0, segs))
  }
  { ..self, holes, }
}

///|
/// Adds a polygonal hole.
pub fn Sketch2D::with_hole_polygon(
  self : Sketch2D,
  pts : Array[Vec2],
) -> Sketch2D {
  let holes = self.holes.copy()
  holes.push(pts)
  { ..self, holes, }
}

///|
/// Adds a slot-shaped hole centered at `(cx, cy)` and rotated by `angle_deg`.
pub fn Sketch2D::with_hole_slot(
  self : Sketch2D,
  cx : Double,
  cy : Double,
  length~ : Double,
  width~ : Double,
  angle_deg~ : Double = 0.0,
  segs~ : Int32 = 16,
) -> Sketch2D {
  let hole = Sketch2D::slot(length, width, segs~)
    .rotate_deg(angle_deg)
    .translate(cx, cy)
  let holes = self.holes.copy()
  holes.push(hole.outer)
  { ..self, holes, }
}

///|
/// Rounds the outer polygon's convex corners with radius `r`, clamping each
/// corner radius so adjacent edges cannot cross.
pub fn Sketch2D::fillet_corners(
  self : Sketch2D,
  r : Double,
  segs~ : Int32 = SKETCH_FILLET_SEGS,
) -> Sketch2D {
  let n = self.outer.length()
  if n < 3 || r <= 0.0 {
    return self
  }
  let s = if segs < 1 { 1 } else { segs }
  let ins : Array[Vec2] = []
  let outs : Array[Vec2] = []
  let centers : Array[Vec2] = []
  let valids : Array[Bool] = []
  for i in 0..<n {
    let prev = self.outer[(i + n - 1) % n]
    let v = self.outer[i]
    let next = self.outer[(i + 1) % n]
    let e1 = sk_sub(prev, v)
    let e2 = sk_sub(next, v)
    let l1 = sk_len(e1)
    let l2 = sk_len(e2)
    let d1 = sk_norm(e1)
    let d2 = sk_norm(e2)
    let cross = sk_cross(d1, d2)
    let mut cos_theta = sk_dot(d1, d2)
    if cos_theta > 1.0 {
      cos_theta = 1.0
    } else if cos_theta < -1.0 {
      cos_theta = -1.0
    }
    let theta = @math.acos(cos_theta)
    let mut valid = cross < -CAD_LENGTH_EPS &&
      theta > @step.TOL_1E3 &&
      theta < @math.PI - @step.TOL_1E3 &&
      l1 > CAD_LENGTH_EPS &&
      l2 > CAD_LENGTH_EPS
    let mut t = 0.0
    if valid {
      let max_t = 0.45 * (if l1 < l2 { l1 } else { l2 })
      t = r / @math.tan(theta / 2.0)
      if t > max_t {
        t = max_t
      }
      if t < @step.TOL_1E6 {
        valid = false
      }
    }
    if valid {
      let in_pt = (v.0 + d1.0 * t, v.1 + d1.1 * t)
      let out_pt = (v.0 + d2.0 * t, v.1 + d2.1 * t)
      let bis = sk_norm((d1.0 + d2.0, d1.1 + d2.1))
      let dist = t / @math.cos(theta / 2.0)
      ins.push(in_pt)
      outs.push(out_pt)
      centers.push((v.0 + bis.0 * dist, v.1 + bis.1 * dist))
    } else {
      ins.push(v)
      outs.push(v)
      centers.push(v)
    }
    valids.push(valid)
  }
  let out : Array[Vec2] = []
  for i in 0..<n {
    if valids[i] {
      let a = ins[i]
      let b = outs[i]
      let c = centers[i]
      let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
      let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
      let mut delta = a1 - a0
      while delta > @math.PI {
        delta = delta - 2.0 * @math.PI
      }
      while delta < -@math.PI {
        delta = delta + 2.0 * @math.PI
      }
      let radius = sk_len(sk_sub(a, c))
      for j in 0..<=s {
        let tt = j.to_double() / s.to_double()
        let ang = a0 + delta * tt
        out.push((c.0 + radius * @math.cos(ang), c.1 + radius * @math.sin(ang)))
      }
    } else {
      out.push(self.outer[i])
    }
  }
  { ..self, outer: sk_ensure_ccw(out), }
}

///|
/// Translates the whole sketch by `(dx, dy)` in the sketch plane.
pub fn Sketch2D::translate(
  self : Sketch2D,
  dx : Double,
  dy : Double,
) -> Sketch2D {
  {
    outer: sk_transform_pts(self.outer, dx, dy, 0.0),
    holes: self.holes.map(fn(h) { sk_transform_pts(h, dx, dy, 0.0) }),
  }
}

///|
/// Rotates the whole sketch about the sketch origin by `deg` degrees.
pub fn Sketch2D::rotate_deg(self : Sketch2D, deg : Double) -> Sketch2D {
  {
    outer: sk_transform_pts(self.outer, 0.0, 0.0, deg),
    holes: self.holes.map(fn(h) { sk_transform_pts(h, 0.0, 0.0, deg) }),
  }
}

///|
/// True when either polygon has a vertex inside the other, which catches a
/// containment case whose edge distance alone would look positive.
fn sk_polygons_overlap(a : Array[Vec2], b : Array[Vec2]) -> Bool {
  for p in a {
    if sk_point_in_polygon(p, b) {
      return true
    }
  }
  for p in b {
    if sk_point_in_polygon(p, a) {
      return true
    }
  }
  false
}

///|
/// Minimum point-to-edge distance between two closed polygons.
fn sk_polygons_min_distance(a : Array[Vec2], b : Array[Vec2]) -> Double {
  if a.length() == 0 || b.length() == 0 {
    return 1.0e18
  }
  let mut best = 1.0e18
  for p in a {
    for j in 0..<b.length() {
      let d = sk_point_segment_distance(p, b[j], b[(j + 1) % b.length()])
      if d < best {
        best = d
      }
    }
  }
  for p in b {
    for j in 0..<a.length() {
      let d = sk_point_segment_distance(p, a[j], a[(j + 1) % a.length()])
      if d < best {
        best = d
      }
    }
  }
  best
}

///|
/// Checks that every hole lies inside the outer boundary with at least
/// `min_margin_mm` clearance, and that holes are not overlapping or closer
/// than `min_margin_mm` to each other. Returns one message per problem.
pub fn Sketch2D::validate_edge_margins(
  self : Sketch2D,
  min_margin_mm : Double,
) -> Array[String] {
  let messages : Array[String] = []
  let n = self.outer.length()
  if n < 3 {
    return ["outer boundary has fewer than 3 points"]
  }
  for i in 0..<self.holes.length() {
    let hole = self.holes[i]
    let mut outside = false
    let mut worst = 1.0e18
    for p in hole {
      if !sk_point_in_polygon(p, self.outer) {
        outside = true
        break
      }
      let mut d = 1.0e18
      for j in 0..<n {
        let a = self.outer[j]
        let b = self.outer[(j + 1) % n]
        let dd = sk_point_segment_distance(p, a, b)
        if dd < d {
          d = dd
        }
      }
      if d < worst {
        worst = d
      }
    }
    if outside {
      messages.push(
        "hole " + (i + 1).to_string() + " protrudes outside the outer boundary",
      )
    } else if worst < min_margin_mm {
      messages.push(
        "hole " +
        (i + 1).to_string() +
        " is only " +
        fmt_double(worst, Some(0.01)) +
        " mm from the outer edge (minimum " +
        fmt_double(min_margin_mm, Some(0.01)) +
        " mm)",
      )
    }
  }
  // Pairwise hole clearance: two bores that touch or crowd each other break
  // the extrusion just as surely as a hole crossing the outer edge.
  for i in 0..<self.holes.length() {
    for j in (i + 1)..<self.holes.length() {
      let overlap = sk_polygons_overlap(self.holes[i], self.holes[j])
      let gap = if overlap {
        0.0
      } else {
        sk_polygons_min_distance(self.holes[i], self.holes[j])
      }
      if gap < min_margin_mm {
        messages.push(
          "hole " +
          (i + 1).to_string() +
          " and hole " +
          (j + 1).to_string() +
          " overlap or are closer than " +
          fmt_double(min_margin_mm, Some(0.01)) +
          " mm (gap " +
          fmt_double(gap, Some(0.01)) +
          " mm)",
        )
      }
    }
  }
  messages
}

///|
/// Punches a mate connector's hole pattern into this sketch at `(cx, cy)`.
///
/// `clearance_mm` is diametral: every hole's diameter grows by it. A bolt
/// circle adds its optional pilot bore first, then the bolt holes; a bearing
/// seat adds one hole of the seat diameter; a single bore adds one hole.
pub fn Sketch2D::punch_mate_holes(
  self : Sketch2D,
  cx : Double,
  cy : Double,
  pattern : HolePattern,
  clearance_mm~ : Double = 0.0,
) -> Sketch2D {
  match pattern {
    BoltCircle(count, bcd_mm, hole_diam_mm, pilot_diam_mm, start_deg) => {
      let mut out = self
      if pilot_diam_mm > 0.0 {
        out = out.with_hole_circle(cx, cy, diam=pilot_diam_mm + clearance_mm)
      }
      let n = if count < 1 { 1 } else { count }
      for i in 0..<n {
        let a = (start_deg + 360.0 * i.to_double() / n.to_double()) *
          @math.PI /
          180.0
        out = out.with_hole_circle(
          cx + bcd_mm / 2.0 * @math.cos(a),
          cy + bcd_mm / 2.0 * @math.sin(a),
          diam=hole_diam_mm + clearance_mm,
        )
      }
      out
    }
    BearingSeat(outer_diam_mm, _bore_diam_mm) =>
      self.with_hole_circle(cx, cy, diam=outer_diam_mm + clearance_mm)
    SingleBore(diam_mm) =>
      self.with_hole_circle(cx, cy, diam=diam_mm + clearance_mm)
  }
}

///|
/// Extrudes the sketch on `plane` by `thickness_mm`. With `centered=true` the
/// solid straddles the plane; otherwise it grows along the plane's normal.
pub fn Sketch2D::extrude_on(
  self : Sketch2D,
  plane : Plane,
  thickness_mm : Double,
  centered~ : Bool = false,
) -> SceneNode {
  let base = ExtrudedProfile::new(self.outer, thickness_mm, holes=self.holes).with_name(
    "sketch2d",
  )
  let half = if centered { thickness_mm / 2.0 } else { 0.0 }
  match plane {
    XY => base.translate(z=-half)
    XZ => base.rotate_x(90.0).translate(y=half)
    YZ => base.rotate_y(90.0).translate(x=-half)
  }
}
