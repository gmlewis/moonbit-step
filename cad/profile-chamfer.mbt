///|
/// VertexSelection selects which vertices a 2D chamfer or fillet operation
/// applies to.
pub(all) enum VertexSelection {
  /// Every non-collinear vertex.
  All
  /// Only vertices that turn toward the material (convex for the profile's
  /// winding).
  ConvexOnly
  /// Only re-entrant vertices.
  ConcaveOnly
  /// Explicit indices into the input profile.
  Indices(Array[Int32])
}

///|
/// ProfileOpError reports why a 2D profile chamfer or fillet was rejected.
pub(all) enum ProfileOpError {
  TooFewVertices
  NonPositiveSize
  FeatureTooLarge(Int32)
  VertexIndexOutOfRange(Int32)
  SelfIntersection
}

///|
/// ProfileOpError::message returns a human-readable diagnostic.
pub fn ProfileOpError::message(self : ProfileOpError) -> String {
  match self {
    TooFewVertices => "a profile chamfer/fillet needs at least three vertices"
    NonPositiveSize =>
      "chamfer distance and fillet radius must be positive and finite"
    FeatureTooLarge(i) =>
      "the chamfer/fillet at vertex \{i} does not fit on its adjacent edges"
    VertexIndexOutOfRange(i) => "vertex index \{i} is out of range"
    SelfIntersection =>
      "the chamfer/fillet would make the profile self-intersect"
  }
}

///|
fn seg_orient(a : Vec2, b : Vec2, c : Vec2) -> Double {
  (b.0 - a.0) * (c.1 - a.1) - (b.1 - a.1) * (c.0 - a.0)
}

///|
fn seg_crosses(a0 : Vec2, a1 : Vec2, b0 : Vec2, b1 : Vec2) -> Bool {
  let o1 = seg_orient(a0, a1, b0)
  let o2 = seg_orient(a0, a1, b1)
  let o3 = seg_orient(b0, b1, a0)
  let o4 = seg_orient(b0, b1, a1)
  o1 * o2 < -1.0e-12 && o3 * o4 < -1.0e-12
}

///|
/// Profile2D::is_simple reports whether the profile is a simple closed polygon:
/// no zero-length edges and no proper edge crossings between non-adjacent
/// edges.
pub fn Profile2D::is_simple(pts : Array[Vec2]) -> Bool {
  let n = pts.length()
  if n < 3 {
    return false
  }
  for i in 0..<n {
    let a0 = pts[i]
    let a1 = pts[(i + 1) % n]
    if (a0.0 - a1.0).abs() < 1.0e-12 && (a0.1 - a1.1).abs() < 1.0e-12 {
      return false
    }
    for j in (i + 1)..<n {
      if j == (i + 1) % n || i == (j + 1) % n {
        continue
      }
      let b0 = pts[j]
      let b1 = pts[(j + 1) % n]
      if seg_crosses(a0, a1, b0, b1) {
        return false
      }
    }
  }
  true
}

///|
fn v2_sub(a : Vec2, b : Vec2) -> Vec2 {
  (a.0 - b.0, a.1 - b.1)
}

///|
fn v2_norm(a : Vec2) -> Vec2 {
  let l = Double::sqrt(a.0 * a.0 + a.1 * a.1)
  if l == 0.0 {
    (1.0, 0.0)
  } else {
    (a.0 / l, a.1 / l)
  }
}

///|
fn v2_dot(a : Vec2, b : Vec2) -> Double {
  a.0 * b.0 + a.1 * b.1
}

///|
/// profile_arc_points samples the minor arc from `t1` to `t2` about `center`.
fn profile_arc_points(
  center : Vec2,
  t1 : Vec2,
  t2 : Vec2,
  segments : Int32,
) -> Array[Vec2] {
  let a0 = @math.atan2(t1.1 - center.1, t1.0 - center.0)
  let a1 = @math.atan2(t2.1 - center.1, t2.0 - center.0)
  let mut delta = a1 - a0
  let two_pi = 2.0 * @math.PI
  while delta > @math.PI {
    delta = delta - two_pi
  }
  while delta <= -@math.PI {
    delta = delta + two_pi
  }
  let rho = Double::sqrt(
    (t1.0 - center.0) * (t1.0 - center.0) +
    (t1.1 - center.1) * (t1.1 - center.1),
  )
  let n = if segments < 1 { 1 } else { segments }
  let out : Array[Vec2] = []
  for i in 0..<=n {
    let t = Double::from_int(i) / Double::from_int(n)
    let ang = a0 + delta * t
    out.push((center.0 + rho * @math.cos(ang), center.1 + rho * @math.sin(ang)))
  }
  out
}

///|
/// profile_vertex_cross returns the signed turn at `cur` for `prev -> cur ->
/// next`. For a counter-clockwise profile a positive value is convex.
fn profile_vertex_cross(prev : Vec2, cur : Vec2, next : Vec2) -> Double {
  (cur.0 - prev.0) * (next.1 - cur.1) - (cur.1 - prev.1) * (next.0 - cur.0)
}

///|
/// profile_selected_mask resolves a `VertexSelection` into per-vertex flags.
fn profile_selected_mask(
  pts : Array[Vec2],
  which : VertexSelection,
) -> Result[Array[Bool], ProfileOpError] {
  let n = pts.length()
  let winding = if polygon_area_2d(pts) >= 0.0 { 1.0 } else { -1.0 }
  let mask : Array[Bool] = []
  for _ in 0..<n {
    mask.push(false)
  }
  match which {
    Indices(idxs) =>
      for raw in idxs {
        if raw < 0 || raw >= n {
          return Err(VertexIndexOutOfRange(raw))
        }
        mask[raw] = true
      }
    _ =>
      for i in 0..<n {
        let prev = pts[(i + n - 1) % n]
        let cur = pts[i]
        let next = pts[(i + 1) % n]
        let cross = profile_vertex_cross(prev, cur, next) * winding
        if cross.abs() < 1.0e-12 {
          continue
        }
        let convex = cross > 0.0
        match which {
          All => mask[i] = true
          ConvexOnly => if convex { mask[i] = true }
          ConcaveOnly => if !convex { mask[i] = true }
          Indices(_) => ()
        }
      }
  }
  Ok(mask)
}

///|
/// profile_edge_lengths returns the length of every edge i -> i+1.
fn profile_edge_lengths(pts : Array[Vec2]) -> Array[Double] {
  let n = pts.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    out.push(
      Double::sqrt((b.0 - a.0) * (b.0 - a.0) + (b.1 - a.1) * (b.1 - a.1)),
    )
  }
  out
}

///|
fn profile_corner_angle(u1 : Vec2, u2 : Vec2) -> Double {
  let c = v2_dot(u1, u2)
  if c > 1.0 {
    0.0
  } else if c < -1.0 {
    @math.PI
  } else {
    @math.acos(c)
  }
}

///|
/// Profile2D::chamfer_vertices truncates selected vertices with a straight
/// bevel.
///
/// `distance` is the leg length measured along the edge toward the previous
/// vertex. When `angle_deg` is supplied it is the angle between the chamfer
/// line and that incoming edge (measured inside the material); the leg along
/// the outgoing edge then follows from the triangle. Without an angle the
/// chamfer has equal legs.
///
/// The input winding is preserved. Convex vertices are cut; re-entrant vertices
/// have their notch beveled. The result is a simple closed polygon suitable for
/// `ExtrudedProfile`.
pub fn Profile2D::chamfer_vertices(
  profile : Array[Vec2],
  distance : Double,
  angle_deg? : Double,
  which~ : VertexSelection = All,
) -> Result[Array[Vec2], ProfileOpError] {
  let n = profile.length()
  if n < 3 {
    return Err(TooFewVertices)
  }
  if !(distance > 0.0) || distance > 1.0e300 {
    return Err(NonPositiveSize)
  }
  let mask = match profile_selected_mask(profile, which) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let t_in : Array[Double] = []
  let t_out : Array[Double] = []
  for _ in 0..<n {
    t_in.push(0.0)
    t_out.push(0.0)
  }
  for i in 0..<n {
    if !mask[i] {
      continue
    }
    let prev = profile[(i + n - 1) % n]
    let cur = profile[i]
    let next = profile[(i + 1) % n]
    let u1 = v2_norm(v2_sub(prev, cur))
    let u2 = v2_norm(v2_sub(next, cur))
    let theta = profile_corner_angle(u1, u2)
    if theta <= 1.0e-9 || theta >= @math.PI - 1.0e-9 {
      continue
    }
    match angle_deg {
      None => {
        t_in[i] = distance
        t_out[i] = distance
      }
      Some(a_deg) => {
        let a = a_deg * @math.PI / 180.0
        let denom = @math.sin(theta + a)
        if denom.abs() < 1.0e-9 {
          return Err(FeatureTooLarge(i))
        }
        t_in[i] = distance
        t_out[i] = distance * @math.sin(a) / denom
        if !(t_out[i] > 0.0) || t_out[i] > 1.0e300 {
          return Err(FeatureTooLarge(i))
        }
      }
    }
  }
  profile_build_corners(profile, mask, t_in, t_out, None, 0)
}

///|
/// Profile2D::fillet_vertices rounds selected vertices with a circular arc of
/// `radius` tangent to both adjacent edges. `segments` controls the arc
/// subdivisions per corner.
///
/// The input winding is preserved. Convex vertices are rounded (material
/// removed); re-entrant vertices are rounded with the arc filling the notch.
pub fn Profile2D::fillet_vertices(
  profile : Array[Vec2],
  radius : Double,
  segments~ : Int32 = 8,
  which~ : VertexSelection = All,
) -> Result[Array[Vec2], ProfileOpError] {
  let n = profile.length()
  if n < 3 {
    return Err(TooFewVertices)
  }
  if !(radius > 0.0) || radius > 1.0e300 {
    return Err(NonPositiveSize)
  }
  let mask = match profile_selected_mask(profile, which) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let t_in : Array[Double] = []
  let t_out : Array[Double] = []
  for _ in 0..<n {
    t_in.push(0.0)
    t_out.push(0.0)
  }
  for i in 0..<n {
    if !mask[i] {
      continue
    }
    let prev = profile[(i + n - 1) % n]
    let cur = profile[i]
    let next = profile[(i + 1) % n]
    let u1 = v2_norm(v2_sub(prev, cur))
    let u2 = v2_norm(v2_sub(next, cur))
    let theta = profile_corner_angle(u1, u2)
    if theta <= 1.0e-9 || theta >= @math.PI - 1.0e-9 {
      continue
    }
    let t = radius / @math.tan(theta / 2.0)
    t_in[i] = t
    t_out[i] = t
  }
  profile_build_corners(profile, mask, t_in, t_out, Some(radius), segments)
}

///|
/// profile_build_corners replaces selected vertices with a chamfer or fillet.
fn profile_build_corners(
  profile : Array[Vec2],
  mask : Array[Bool],
  t_in : Array[Double],
  t_out : Array[Double],
  fillet_radius : Double?,
  segments : Int32,
) -> Result[Array[Vec2], ProfileOpError] {
  let n = profile.length()
  let lengths = profile_edge_lengths(profile)
  // Edge i -> i+1 consumes t_out[i] at its start and t_in[i+1] at its end.
  for i in 0..<n {
    let j = (i + 1) % n
    if t_out[i] + t_in[j] > lengths[i] + 1.0e-9 {
      return Err(FeatureTooLarge(i))
    }
  }
  let out : Array[Vec2] = []
  for i in 0..<n {
    if !mask[i] {
      out.push(profile[i])
      continue
    }
    let prev = profile[(i + n - 1) % n]
    let cur = profile[i]
    let next = profile[(i + 1) % n]
    let u1 = v2_norm(v2_sub(prev, cur))
    let u2 = v2_norm(v2_sub(next, cur))
    let t1 = (cur.0 + u1.0 * t_in[i], cur.1 + u1.1 * t_in[i])
    let t2 = (cur.0 + u2.0 * t_out[i], cur.1 + u2.1 * t_out[i])
    match fillet_radius {
      None => {
        out.push(t1)
        out.push(t2)
      }
      Some(radius) => {
        let theta = profile_corner_angle(u1, u2)
        let bis = v2_norm((u1.0 + u2.0, u1.1 + u2.1))
        let center_dist = radius / @math.sin(theta / 2.0)
        let center = (cur.0 + bis.0 * center_dist, cur.1 + bis.1 * center_dist)
        let arc = profile_arc_points(center, t1, t2, segments)
        out.push_iter(arc.iter())
      }
    }
  }
  if !Profile2D::is_simple(out) {
    return Err(SelfIntersection)
  }
  Ok(out)
}
