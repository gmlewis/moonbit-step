///|
// Exact in-memory analysis for the intent-based shape graph.
//
// This module deliberately lives in the `cad` package: `Profile2D`,
// `ChamferedPrism`, `RevolvedProfile`, and the compiler helpers are private to
// this package, and the analysis must mirror the same face-emission rules the
// STEP compilers use.
//
// The analysis is analytic, not tessellated. Shapes that cannot be analysed
// exactly return a typed `NotAnalytic` error; they are never silently
// approximated.

///|
/// SurfaceInventory counts the analytic surface faces a shape emits.
pub(all) struct SurfaceInventory {
  plane : Int32
  cylinder : Int32
  cone : Int32
  sphere : Int32
  torus : Int32
  bspline : Int32
  swept : Int32
  other : Int32
}

///|
/// SurfaceInventory::empty returns a zero inventory.
pub fn SurfaceInventory::empty() -> SurfaceInventory {
  {
    plane: 0,
    cylinder: 0,
    cone: 0,
    sphere: 0,
    torus: 0,
    bspline: 0,
    swept: 0,
    other: 0,
  }
}

///|
/// SurfaceInventory::add returns the component-wise sum of two inventories.
pub fn SurfaceInventory::add(
  self : SurfaceInventory,
  other : SurfaceInventory,
) -> SurfaceInventory {
  {
    plane: self.plane + other.plane,
    cylinder: self.cylinder + other.cylinder,
    cone: self.cone + other.cone,
    sphere: self.sphere + other.sphere,
    torus: self.torus + other.torus,
    bspline: self.bspline + other.bspline,
    swept: self.swept + other.swept,
    other: self.other + other.other,
  }
}

///|
/// SurfaceInventory::total returns the total number of counted faces.
pub fn SurfaceInventory::total(self : SurfaceInventory) -> Int32 {
  self.plane +
  self.cylinder +
  self.cone +
  self.sphere +
  self.torus +
  self.bspline +
  self.swept +
  self.other
}

///|
fn an_inventory(
  plane : Int32,
  cylinder : Int32,
  cone : Int32,
  sphere : Int32,
  torus : Int32,
  bspline : Int32,
  swept : Int32,
  other : Int32,
) -> SurfaceInventory {
  { plane, cylinder, cone, sphere, torus, bspline, swept, other, }
}

///|
/// SectionRing is one material annulus of a cross-section.
pub(all) struct SectionRing {
  inner_radius_mm : Double
  outer_radius_mm : Double
}

///|
/// Section is an exact horizontal cross-section of a shape in its local frame.
pub(all) struct Section {
  z_mm : Double
  area_mm2 : Double
  perimeter_mm : Double
  outer_radius_mm : Double
  inner_radius_mm : Double
  rings : Array[SectionRing]
}

///|
/// AnalysisError reports why an analytic result is unavailable.
pub(all) enum AnalysisError {
  NotAnalytic(String)
  EmptySection
  UnsupportedTransform(String)
  DegenerateProfile
}

///|
/// AnalysisError::message returns a human-readable diagnostic.
pub fn AnalysisError::message(self : AnalysisError) -> String {
  match self {
    NotAnalytic(reason) => "not analytically analyzable: " + reason
    EmptySection => "the section plane does not intersect the material"
    UnsupportedTransform(name) =>
      "world-z sections are not exact for the transform: " + name
    DegenerateProfile => "the profile is degenerate"
  }
}

///|
fn an_perimeter(pts : Array[Vec2]) -> Double {
  let n = pts.length()
  if n < 2 {
    return 0.0
  }
  let mut sum = 0.0
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    let dx = a.0 - b.0
    let dy = a.1 - b.1
    sum = sum + Double::sqrt(dx * dx + dy * dy)
  }
  sum
}

///|
fn an_max_radius(pts : Array[Vec2]) -> Double {
  let mut r = 0.0
  for p in pts {
    let d = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if d > r {
      r = d
    }
  }
  r
}

///|
fn an_min_radius(pts : Array[Vec2]) -> Double {
  let mut r = 1.0e300
  for p in pts {
    let d = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if d < r {
      r = d
    }
  }
  if r == 1.0e300 {
    0.0
  } else {
    r
  }
}

///|
/// an_polygon_moments returns the signed area and signed first moments
/// `(area, ∫x dA, ∫y dA)` of a polygon. A counter-clockwise loop has a
/// positive area; reversing the loop negates both the area and the moments, so
/// outer loops wound CCW and holes wound CW can simply be summed.
fn an_polygon_moments(pts : Array[Vec2]) -> (Double, Double, Double) {
  let n = pts.length()
  if n < 3 {
    return (0.0, 0.0, 0.0)
  }
  let mut a = 0.0
  let mut mx = 0.0
  let mut my = 0.0
  for i in 0..<n {
    let p = pts[i]
    let q = pts[(i + 1) % n]
    let cross = p.0 * q.1 - q.0 * p.1
    a = a + cross
    mx = mx + (p.0 + q.0) * cross
    my = my + (p.1 + q.1) * cross
  }
  (a / 2.0, mx / 6.0, my / 6.0)
}

///|
/// an_sort_unique sorts radii ascending and merges values closer than `tol`.
fn an_sort_unique(radii : Array[Double], tol : Double) -> Array[Double] {
  let sorted = radii.copy()
  let n = sorted.length()
  for i in 1..<n {
    let v = sorted[i]
    let mut j = i - 1
    while j >= 0 && sorted[j] > v {
      sorted[j + 1] = sorted[j]
      j = j - 1
    }
    sorted[j + 1] = v
  }
  let out : Array[Double] = []
  for r in sorted {
    let value = if r < 0.0 { 0.0 } else { r }
    let keep = match out.last() {
      Some(prev) => value - prev > tol
      None => true
    }
    if keep {
      out.push(value)
    }
  }
  out
}

///|
/// an_arc_contains reports whether `(r, z)` lies on the minor arc from `a` to
/// `b` about center `c`.
fn an_arc_contains(
  c : Vec2,
  a : Vec2,
  b : Vec2,
  r : Double,
  z : Double,
) -> Bool {
  let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
  let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
  let delta = rev_norm_angle(a1 - a0)
  let ac = @math.atan2(z - c.1, r - c.0)
  let rel = rev_norm_angle(ac - a0)
  let two_pi = 2.0 * @math.PI
  let eps = CAD_LENGTH_EPS
  let on = if delta >= 0.0 {
    (rel >= -eps && rel <= delta + eps) ||
    (rel <= 0.0 && rel + two_pi <= delta + eps)
  } else {
    (rel <= eps && rel >= delta - eps) ||
    (rel >= 0.0 && rel - two_pi >= delta - eps)
  }
  on
}

///|
/// an_rev_contains reports whether the point `(r, z0)` lies in the closed
/// material region of a revolved profile. A vertical ray is cast upward and
/// horizontal cap bands at `z0` count as material, so a cap plane yields the
/// closure of the solid (for example the full disc at the floor of a cup).
fn an_rev_contains(segs : Array[RevSegment], z0 : Double, r : Double) -> Bool {
  let eps = CAD_LENGTH_EPS
  // A horizontal boundary at the section plane is a cap: the closure of the
  // solid includes the whole radial interval it spans.
  for seg in segs {
    match seg {
      RevLine(a, b) =>
        if (a.1 - b.1).abs() < eps && (z0 - a.1).abs() < @step.TOL_1E7 {
          let lo = if a.0 < b.0 { a.0 } else { b.0 }
          let hi = if a.0 > b.0 { a.0 } else { b.0 }
          if r >= lo - eps && r <= hi + eps {
            return true
          }
        }
      RevArc(_, _, _) => ()
    }
  }
  let crossings : Array[Double] = []
  for seg in segs {
    match seg {
      RevLine(a, b) => {
        let dz = b.1 - a.1
        if dz.abs() < eps {
          let lo = if a.0 < b.0 { a.0 } else { b.0 }
          let hi = if a.0 > b.0 { a.0 } else { b.0 }
          if a.1 > z0 + eps && r >= lo - eps && r <= hi + eps {
            crossings.push(a.1)
          }
        } else {
          let dr = b.0 - a.0
          if dr.abs() > eps {
            let t = (r - a.0) / dr
            if t > -eps && t < 1.0 + eps {
              let z = a.1 + t * dz
              if z > z0 + eps {
                crossings.push(z)
              }
            }
          }
        }
      }
      RevArc(a, b, c) => {
        let rho = rev_dist2(a, c)
        let dr = r - c.0
        let disc = rho * rho - dr * dr
        if disc > @step.TOL_1E14 {
          let s = Double::sqrt(disc)
          for zc in [c.1 + s, c.1 - s] {
            if zc > z0 + eps && an_arc_contains(c, a, b, r, zc) {
              crossings.push(zc)
            }
          }
        }
      }
    }
  }
  // Two adjacent bands share a vertex on the ray; count that crossing once.
  let unique = an_sort_unique(crossings, @step.TOL_1E7)
  unique.length() % 2 == 1
}

///|
/// an_rev_section intersects a revolved profile with the plane `z = z0`.
fn an_rev_section(
  rev : RevolvedProfile,
  z0 : Double,
) -> Result[Section, AnalysisError] {
  match rev.validate() {
    Err(_) => return Err(DegenerateProfile)
    Ok(_) => ()
  }
  let segs = rev.segments
  if segs.length() == 0 {
    return Err(DegenerateProfile)
  }
  let radii : Array[Double] = [0.0]
  for seg in segs {
    match seg {
      RevLine(a, b) => {
        let dz = b.1 - a.1
        if dz.abs() < CAD_LENGTH_EPS {
          // A horizontal band is a cap: it lies in the section plane only when
          // z0 equals that plane.
          if (z0 - a.1).abs() < @step.TOL_1E7 {
            radii.push(a.0)
            radii.push(b.0)
          }
        } else {
          let t = (z0 - a.1) / dz
          if t >= -CAD_LENGTH_EPS && t <= 1.0 + CAD_LENGTH_EPS {
            radii.push(a.0 + t * (b.0 - a.0))
          }
        }
      }
      RevArc(a, b, c) => {
        let rho = rev_dist2(a, c)
        let dzc = z0 - c.1
        let disc = rho * rho - dzc * dzc
        if disc > @step.TOL_1E14 {
          let dr = Double::sqrt(disc)
          for cand in [c.0 + dr, c.0 - dr] {
            if cand >= -CAD_LENGTH_EPS && an_arc_contains(c, a, b, cand, z0) {
              radii.push(cand)
            }
          }
        }
        // A tangent plane (disc ~ 0) touches the arc at one point; it bounds
        // no material, so it contributes no section ring.
      }
    }
  }
  let candidates = an_sort_unique(radii, @step.TOL_1E7)
  let intervals : Array[(Double, Double)] = []
  let mut i = 0
  while i + 1 < candidates.length() {
    let ri = candidates[i]
    let ro = candidates[i + 1]
    if ro - ri > CAD_LENGTH_EPS {
      let mid = (ri + ro) / 2.0
      if an_rev_contains(segs, z0, mid) {
        if intervals.length() > 0 {
          let prev = intervals[intervals.length() - 1]
          if ri <= prev.1 + @step.TOL_1E7 {
            intervals[intervals.length() - 1] = (prev.0, ro)
          } else {
            intervals.push((ri, ro))
          }
        } else {
          intervals.push((ri, ro))
        }
      }
    }
    i = i + 1
  }
  let rings : Array[SectionRing] = []
  let mut area = 0.0
  let mut perimeter = 0.0
  let mut outer = 0.0
  let mut inner = 1.0e300
  for iv in intervals {
    let (ri, ro) = iv
    rings.push({ inner_radius_mm: ri, outer_radius_mm: ro, })
    area = area + @math.PI * (ro * ro - ri * ri)
    perimeter = perimeter + 2.0 * @math.PI * (ro + ri)
    if ro > outer {
      outer = ro
    }
    if ri < inner {
      inner = ri
    }
  }
  if rings.length() == 0 || area <= @step.TOL_1E12 {
    return Err(EmptySection)
  }
  if inner == 1.0e300 {
    inner = 0.0
  }
  Ok({
    z_mm: z0,
    area_mm2: area,
    perimeter_mm: perimeter,
    outer_radius_mm: outer,
    inner_radius_mm: inner,
    rings,
  })
}

///|
/// an_arc_volume_integrals returns `(∫ r² dz, ∫ z r² dz)` along a minor arc.
fn an_arc_volume_integrals(a : Vec2, b : Vec2, c : Vec2) -> (Double, Double) {
  let rho = rev_dist2(a, c)
  let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
  let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
  let delta = rev_norm_angle(a1 - a0)
  let t0 = a0
  let t1 = a0 + delta
  let f2 = fn(theta : Double) -> Double {
    let s = @math.sin(theta)
    let s2 = @math.sin(2.0 * theta)
    let s3 = s * s * s
    rho *
    (
      c.0 * c.0 * s +
      2.0 * c.0 * rho * (theta / 2.0 + s2 / 4.0) +
      rho * rho * (s - s3 / 3.0)
    )
  }
  let fz = fn(theta : Double) -> Double {
    let s = @math.sin(theta)
    let co = @math.cos(theta)
    let s2 = @math.sin(2.0 * theta)
    let s3 = s * s * s
    let co3 = co * co * co
    let co4 = co3 * co
    rho *
    (
      c.1 * c.0 * c.0 * s +
      2.0 * c.1 * c.0 * rho * (theta / 2.0 + s2 / 4.0) +
      c.1 * rho * rho * (s - s3 / 3.0) +
      rho * c.0 * c.0 * (s * s / 2.0) +
      2.0 * rho * rho * c.0 * (-co3 / 3.0) +
      rho * rho * rho * (-co4 / 4.0)
    )
  }
  (f2(t1) - f2(t0), fz(t1) - fz(t0))
}

///|
/// an_rev_line_volume_integrals returns `(∫ r² dz, ∫ z r² dz)` along a line.
fn an_rev_line_volume_integrals(a : Vec2, b : Vec2) -> (Double, Double) {
  let dz = b.1 - a.1
  let dr = b.0 - a.0
  let i2 = dz * (a.0 * a.0 + a.0 * b.0 + b.0 * b.0) / 3.0
  let int_r2 = a.0 * a.0 + a.0 * dr + dr * dr / 3.0
  let int_t = a.0 * a.0 / 2.0 + 2.0 * a.0 * dr / 3.0 + dr * dr / 4.0
  let iz = dz * (a.1 * int_r2 + dz * int_t)
  (i2, iz)
}

///|
/// an_rev_volume_centroid returns `(volume, centroid_z)` for a revolved profile.
fn an_rev_volume_centroid(rev : RevolvedProfile) -> (Double, Double) {
  match rev.validate() {
    Err(_) => return (0.0, 0.0)
    Ok(_) => ()
  }
  let mut i2 = 0.0
  let mut iz = 0.0
  for seg in rev.segments {
    let (a2, az) = match seg {
      RevLine(a, b) => an_rev_line_volume_integrals(a, b)
      RevArc(a, b, c) => an_arc_volume_integrals(a, b, c)
    }
    i2 = i2 + a2
    iz = iz + az
  }
  let volume = @math.PI * i2.abs()
  let zc = if i2.abs() < @step.TOL_1E12 { 0.0 } else { iz / i2 }
  (volume, zc)
}

///|
fn an_lerp_inset(levels : Array[(Double, Double)], z : Double) -> Double? {
  let n = levels.length()
  if n == 0 {
    return None
  }
  if z < levels[0].0 - CAD_LENGTH_EPS || z > levels[n - 1].0 + CAD_LENGTH_EPS {
    return None
  }
  if n == 1 {
    return Some(levels[0].1)
  }
  for i in 0..<(n - 1) {
    let (z0, v0) = levels[i]
    let (z1, v1) = levels[i + 1]
    if z >= z0 - CAD_LENGTH_EPS && z <= z1 + CAD_LENGTH_EPS {
      if (z1 - z0).abs() < @step.TOL_1E12 {
        return Some(v1)
      }
      let t = (z - z0) / (z1 - z0)
      return Some(v0 + t * (v1 - v0))
    }
  }
  Some(levels[n - 1].1)
}

///|
/// an_prism_section_props computes the exact section area, perimeter, signed
/// first moments, radii and rings of a chamfered prism at `z`.
fn an_prism_section_props(
  prism : ChamferedPrism,
  z : Double,
) -> Result[
  (Double, Double, Double, Double, Double, Double, Array[SectionRing]),
  AnalysisError,
] {
  let inset = match an_lerp_inset(prism.levels, z) {
    Some(v) => v
    None => return Err(EmptySection)
  }
  let base = force_ccw(prism.base)
  let ring = match chamfer_inset(base, inset) {
    Some(r) => r
    None => return Err(DegenerateProfile)
  }
  let (outer_area, mx0, my0) = an_polygon_moments(ring)
  let mut mx = mx0
  let mut my = my0
  let mut area = outer_area
  let mut perimeter = an_perimeter(ring)
  let outer_radius = an_max_radius(ring)
  let mut inner_radius = 0.0
  let mut have_hole = false
  let rings : Array[SectionRing] = []
  match prism.hole {
    Some(h) => {
      let hccw = force_ccw(h)
      let hole_ring = match prism.hole_levels {
        Some(hls) =>
          match an_lerp_inset(hls, z) {
            Some(inset_h) =>
              match chamfer_inset(hccw, inset_h) {
                Some(r) => r
                None => return Err(DegenerateProfile)
              }
            None => return Err(EmptySection)
          }
        None => hccw
      }
      let (hole_area, hx, hy) = an_polygon_moments(hole_ring)
      area = area - hole_area
      mx = mx - hx
      my = my - hy
      perimeter = perimeter + an_perimeter(hole_ring)
      rings.push({
        inner_radius_mm: 0.0,
        outer_radius_mm: an_max_radius(hole_ring),
      })
      let min_h = an_min_radius(hole_ring)
      inner_radius = if have_hole {
        if min_h < inner_radius {
          min_h
        } else {
          inner_radius
        }
      } else {
        min_h
      }
      have_hole = true
    }
    None => ()
  }
  match prism.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let bore_area = @math.PI * rb * rb
      area = area - bore_area
      mx = mx - bore_area * center.0
      my = my - bore_area * center.1
      perimeter = perimeter + 2.0 * @math.PI * rb
      rings.push({ inner_radius_mm: 0.0, outer_radius_mm: rb, })
      let dist = Double::sqrt(center.0 * center.0 + center.1 * center.1)
      let min_bore = if dist > rb { dist - rb } else { 0.0 }
      inner_radius = if have_hole {
        if min_bore < inner_radius {
          min_bore
        } else {
          inner_radius
        }
      } else {
        min_bore
      }
      have_hole = true
    }
    None => ()
  }
  if !have_hole {
    inner_radius = 0.0
  }
  if area <= @step.TOL_1E12 {
    return Err(EmptySection)
  }
  Ok((area, perimeter, mx, my, outer_radius, inner_radius, rings))
}

///|
/// an_prism_section returns a `Section` for a chamfered prism.
fn an_prism_section(
  prism : ChamferedPrism,
  z : Double,
) -> Result[Section, AnalysisError] {
  let (area, perimeter, _mx, _my, outer, inner, rings) = match
    an_prism_section_props(prism, z) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: perimeter,
    outer_radius_mm: outer,
    inner_radius_mm: inner,
    rings,
  })
}

///|
/// socketed_pocket_across_flats returns the socket width across flats at `z`,
/// including the linear lead-in flare near the mouth.
fn socketed_pocket_across_flats(g : SocketGeometry, z : Double) -> Double {
  let span = g.top_z - g.mid_z
  let t = if span > CAD_DEGENERATE_EPS {
    socket_clamp01((z - g.mid_z) / span)
  } else {
    0.0
  }
  g.across_flats + 2.0 * g.lead * t
}

///|
/// an_socketed_section returns the exact section of a socketed solid at local
/// `z`. Inside the socket the section is the body section minus the hexagonal
/// pocket; the reported inner radius is the hexagon's inradius and the area and
/// perimeter are exact.
fn an_conical_socket_section(
  s : SocketedSolid,
  z : Double,
) -> Result[Section, AnalysisError] {
  let g = match conical_socket_geometry(s) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  let base = match s.body.section_at(z) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if z < g.floor_apex - CAD_LENGTH_EPS || z > g.top_z + CAD_LENGTH_EPS {
    return Ok(base)
  }
  let pocket_area = conical_socket_area_at(g, z)
  let area = base.area_mm2 - pocket_area
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  let inner = Double::sqrt(pocket_area / @math.PI)
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: base.perimeter_mm + conical_socket_void_perimeter(g, z),
    outer_radius_mm: base.outer_radius_mm,
    inner_radius_mm: inner,
    rings: [{ inner_radius_mm: inner, outer_radius_mm: base.outer_radius_mm, }],
  })
}

///|
fn an_socketed_section(
  s : SocketedSolid,
  z : Double,
) -> Result[Section, AnalysisError] {
  if s.conical {
    return an_conical_socket_section(s, z)
  }
  let g = match socketed_geometry(s) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  let base = match s.body.section_at(z) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if z < g.floor_z - CAD_LENGTH_EPS || z > g.top_z + CAD_LENGTH_EPS {
    return Ok(base)
  }
  let af_z = socketed_pocket_across_flats(g, z)
  let pocket_area = Double::sqrt(3.0) / 2.0 * af_z * af_z
  let pocket_perimeter = 2.0 * Double::sqrt(3.0) * af_z
  let area = base.area_mm2 - pocket_area
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: base.perimeter_mm + pocket_perimeter,
    outer_radius_mm: base.outer_radius_mm,
    inner_radius_mm: af_z / 2.0,
    rings: [
      { inner_radius_mm: af_z / 2.0, outer_radius_mm: base.outer_radius_mm, },
    ],
  })
}

///|
/// an_prism_breakpoints returns every axial breakpoint of the outer ring stack
/// and the hole ring stack. Integrating across these sub-bands keeps the net
/// area piecewise quadratic, so Simpson's rule is exact even when the hole has
/// a lead-in level that the outer stack does not.
fn an_prism_breakpoints(prism : ChamferedPrism) -> Array[Double] {
  let zs : Array[Double] = []
  for level in prism.levels {
    zs.push(level.0)
  }
  match prism.hole_levels {
    Some(hls) =>
      for level in hls {
        zs.push(level.0)
      }
    None => ()
  }
  an_sort_unique(zs, CAD_LENGTH_EPS)
}

///|
/// an_prism_volume_centroid integrates the prismatoid bands exactly.
fn an_prism_volume_centroid(prism : ChamferedPrism) -> (Double, Vec3) {
  let zs = an_prism_breakpoints(prism)
  let n = zs.length()
  if n < 2 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  let mut volume = 0.0
  let mut mx_total = 0.0
  let mut my_total = 0.0
  let mut mz_total = 0.0
  for i in 0..<(n - 1) {
    let z0 = zs[i]
    let z1 = zs[i + 1]
    let dz = z1 - z0
    if dz <= 0.0 {
      continue
    }
    let zm = (z0 + z1) / 2.0
    let (a0, _, mx0, my0, _, _, _) = match an_prism_section_props(prism, z0) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let (am, _, mxm, mym, _, _, _) = match an_prism_section_props(prism, zm) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let (a1, _, mx1, my1, _, _, _) = match an_prism_section_props(prism, z1) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let ia = (a0 + 4.0 * am + a1) / 6.0
    let ita = (2.0 * am + a1) / 6.0
    volume = volume + dz * ia
    mx_total = mx_total + dz * (mx0 + 4.0 * mxm + mx1) / 6.0
    my_total = my_total + dz * (my0 + 4.0 * mym + my1) / 6.0
    mz_total = mz_total + dz * (z0 * ia + dz * ita)
  }
  if volume <= @step.TOL_1E12 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx_total / volume, my_total / volume, mz_total / volume))
}

///|
/// an_calib_rings reproduces the ring stack used by the calibration block
/// compiler.
fn an_calib_rings(block : CalibrationChamferBlock) -> Array[(Double, Double)] {
  let h = block.height_mm
  let rings : Array[(Double, Double)] = []
  rings.push((0.0, 0.0))
  let r = block.fillet_radius_mm
  if r > 0.0 {
    rings.push((h - r, 0.0))
    let segs = if block.fillet_segments <= 0 {
      8
    } else {
      block.fillet_segments
    }
    for i in 1..<=segs {
      let phi = i.to_double() * (@math.PI / 2.0) / segs.to_double()
      let offset = r - r * @math.cos(phi)
      let z = h - r + r * @math.sin(phi)
      rings.push((z, offset))
    }
  } else if block.chamfer_size_mm > 0.0 {
    let c = block.chamfer_size_mm
    rings.push((h - c, 0.0))
    rings.push((h, c))
  } else {
    rings.push((h, 0.0))
  }
  rings
}

///|
fn an_calib_section_props(
  block : CalibrationChamferBlock,
  z : Double,
) -> Result[(Double, Double, Double, Double, Double), AnalysisError] {
  let rings = an_calib_rings(block)
  let inset = match an_lerp_inset(rings, z) {
    Some(v) => v
    None => return Err(EmptySection)
  }
  let x0 = inset
  let x1 = block.length_mm - inset
  let y0 = inset
  let y1 = block.width_mm - inset
  let sx = x1 - x0
  let sy = y1 - y0
  if sx <= 0.0 || sy <= 0.0 {
    return Err(EmptySection)
  }
  let area = sx * sy
  let perimeter = 2.0 * (sx + sy)
  let cx = (x0 + x1) / 2.0
  let cy = (y0 + y1) / 2.0
  let ax = an_max2(x0.abs(), x1.abs())
  let ay = an_max2(y0.abs(), y1.abs())
  let max_r = Double::sqrt(ax * ax + ay * ay)
  Ok((area, perimeter, area * cx, area * cy, max_r))
}

///|
fn an_calib_section(
  block : CalibrationChamferBlock,
  z : Double,
) -> Result[Section, AnalysisError] {
  let (area, perimeter, _mx, _my, outer) = match
    an_calib_section_props(block, z) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: perimeter,
    outer_radius_mm: outer,
    inner_radius_mm: 0.0,
    rings: [{ inner_radius_mm: 0.0, outer_radius_mm: outer, }],
  })
}

///|
fn an_calib_volume_centroid(block : CalibrationChamferBlock) -> (Double, Vec3) {
  let rings = an_calib_rings(block)
  let n = rings.length()
  if n < 2 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  let mut volume = 0.0
  let mut mx_total = 0.0
  let mut my_total = 0.0
  let mut mz_total = 0.0
  for i in 0..<(n - 1) {
    let z0 = rings[i].0
    let z1 = rings[i + 1].0
    let dz = z1 - z0
    if dz <= 0.0 {
      continue
    }
    let zm = (z0 + z1) / 2.0
    let (a0, _, mx0, my0, _) = match an_calib_section_props(block, z0) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let (am, _, mxm, mym, _) = match an_calib_section_props(block, zm) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let (a1, _, mx1, my1, _) = match an_calib_section_props(block, z1) {
      Ok(v) => v
      Err(_) => return (0.0, (0.0, 0.0, 0.0))
    }
    let ia = (a0 + 4.0 * am + a1) / 6.0
    let ita = (2.0 * am + a1) / 6.0
    volume = volume + dz * ia
    mx_total = mx_total + dz * (mx0 + 4.0 * mxm + mx1) / 6.0
    my_total = my_total + dz * (my0 + 4.0 * mym + my1) / 6.0
    mz_total = mz_total + dz * (z0 * ia + dz * ita)
  }
  if volume <= @step.TOL_1E12 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx_total / volume, my_total / volume, mz_total / volume))
}

///|
/// an_poly_loops_props computes the exact section area, perimeter and signed
/// first moments of a polygonal profile (outer plus holes), without a round
/// bore.
fn an_poly_loops_props(
  profile : Profile2D,
) -> (Double, Double, Double, Double, Double, Double, Array[SectionRing]) {
  let outer = force_ccw(profile.outer)
  let (outer_area, mx0, my0) = an_polygon_moments(outer)
  let mut mx = mx0
  let mut my = my0
  let mut area = outer_area
  let mut perimeter = an_perimeter(outer)
  let outer_radius = an_max_radius(outer)
  let mut inner_radius = 0.0
  let mut have_hole = false
  let rings : Array[SectionRing] = []
  for h in profile.holes {
    if h.length() < 3 {
      continue
    }
    let hole = force_cw(h)
    let (hole_area, hx, hy) = an_polygon_moments(hole)
    area = area + hole_area
    mx = mx + hx
    my = my + hy
    perimeter = perimeter + an_perimeter(hole)
    rings.push({ inner_radius_mm: 0.0, outer_radius_mm: an_max_radius(hole), })
    let min_h = an_min_radius(hole)
    inner_radius = if have_hole {
      if min_h < inner_radius {
        min_h
      } else {
        inner_radius
      }
    } else {
      min_h
    }
    have_hole = true
  }
  if !have_hole {
    inner_radius = 0.0
  }
  (area, perimeter, mx, my, outer_radius, inner_radius, rings)
}

///|
/// an_profile_props adds an optional analytic round bore to the polygonal
/// profile properties.
fn an_profile_props(
  profile : Profile2D,
  round_bore : (Vec2, Double)?,
) -> (Double, Double, Double, Double, Double, Double, Array[SectionRing]) {
  let (area0, perimeter0, mx0, my0, outer_radius, inner_radius0, rings0) = an_poly_loops_props(
    profile,
  )
  let mut area = area0
  let mut perimeter = perimeter0
  let mut mx = mx0
  let mut my = my0
  let mut inner_radius = inner_radius0
  let mut have_hole = rings0.length() > 0
  let rings = rings0.copy()
  match round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let bore_area = @math.PI * rb * rb
      area = area - bore_area
      mx = mx - bore_area * center.0
      my = my - bore_area * center.1
      perimeter = perimeter + 2.0 * @math.PI * rb
      rings.push({ inner_radius_mm: 0.0, outer_radius_mm: rb, })
      let dist = Double::sqrt(center.0 * center.0 + center.1 * center.1)
      let min_bore = if dist > rb { dist - rb } else { 0.0 }
      inner_radius = if have_hole {
        if min_bore < inner_radius {
          min_bore
        } else {
          inner_radius
        }
      } else {
        min_bore
      }
      have_hole = true
    }
    None => ()
  }
  if !have_hole {
    inner_radius = 0.0
  }
  (area, perimeter, mx, my, outer_radius, inner_radius, rings)
}

///|
/// an_extruded_props computes the exact section area, perimeter and signed
/// first moments of an extruded profile.
fn an_extruded_props(
  extrusion : ExtrudedProfile,
) -> (Double, Double, Double, Double, Double, Double, Array[SectionRing]) {
  an_profile_props(extrusion.profile, extrusion.round_bore)
}

///|
fn an_max2(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn an_extruded_section(
  extrusion : ExtrudedProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  if z < -CAD_LENGTH_EPS || z > extrusion.height_mm + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  if extrusion.height_mm <= 0.0 || extrusion.profile.outer.length() < 3 {
    return Err(DegenerateProfile)
  }
  let (area, perimeter, _mx, _my, outer, inner, rings) = an_extruded_props(
    extrusion,
  )
  if area <= @step.TOL_1E12 {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: perimeter,
    outer_radius_mm: outer,
    inner_radius_mm: inner,
    rings,
  })
}

///|
fn an_extruded_volume_centroid(extrusion : ExtrudedProfile) -> (Double, Vec3) {
  if extrusion.height_mm <= 0.0 || extrusion.profile.outer.length() < 3 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  let (area, _p, mx, my, _outer, _inner, _rings) = an_extruded_props(extrusion)
  let volume = area * extrusion.height_mm
  if area <= @step.TOL_1E12 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx / area, my / area, extrusion.height_mm / 2.0))
}

///|
/// an_conical_scale returns the profile scale at local z. The apex lies at
/// z = apex_distance_mm, so the large end at z = 0 has scale 1.
fn an_conical_scale(e : ConicalExtrusion, z : Double) -> Double {
  (e.apex_distance_mm - z) / e.apex_distance_mm
}

///|
fn an_conical_section(
  e : ConicalExtrusion,
  z : Double,
) -> Result[Section, AnalysisError] {
  let h = e.height_mm
  let d = e.apex_distance_mm
  if h <= 0.0 || d <= h || e.profile.outer.length() < 3 {
    return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > h + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let s = an_conical_scale(e, z)
  let (poly_area, poly_perimeter, _mx, _my, outer_radius, inner_radius, rings0) = an_poly_loops_props(
    e.profile,
  )
  let mut area = poly_area * s * s
  let mut perimeter = poly_perimeter * s
  let mut inner = inner_radius * s
  let rings = rings0.map(fn(r) {
    { inner_radius_mm: 0.0, outer_radius_mm: r.outer_radius_mm * s, }
  })
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let bore_area = @math.PI * rb * rb
      area = area - bore_area
      perimeter = perimeter + 2.0 * @math.PI * rb
      rings.push({ inner_radius_mm: 0.0, outer_radius_mm: rb, })
      let dist = Double::sqrt(center.0 * center.0 + center.1 * center.1)
      let min_bore = if dist > rb { dist - rb } else { 0.0 }
      inner = if rings0.length() > 0 {
        if min_bore < inner {
          min_bore
        } else {
          inner
        }
      } else {
        min_bore
      }
    }
    None => ()
  }
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: perimeter,
    outer_radius_mm: outer_radius * s,
    inner_radius_mm: inner,
    rings,
  })
}

///|
fn an_conical_volume_centroid(e : ConicalExtrusion) -> (Double, Vec3) {
  let h = e.height_mm
  let d = e.apex_distance_mm
  if h <= 0.0 || d <= h || e.profile.outer.length() < 3 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  let k = (d - h) / d
  let (poly_area, _p, poly_mx, poly_my, _outer, _inner, _rings) = an_poly_loops_props(
    e.profile,
  )
  // The polygonal part scales as s(z)^2 in area and s(z)^3 in first moment.
  let s2_int = h * (1.0 + k + k * k) / 3.0
  let s3_int = h * (1.0 + k) * (1.0 + k * k) / 4.0
  let z_s2_int = h * h / 2.0 -
    2.0 * h * h * h / (3.0 * d) +
    h * h * h * h / (4.0 * d * d)
  let mut volume = poly_area * s2_int
  let mut mx = poly_mx * s3_int
  let mut my = poly_my * s3_int
  let mut mz = poly_area * z_s2_int
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let bore_area = @math.PI * rb * rb
      volume = volume - bore_area * h
      mx = mx - bore_area * center.0 * h
      my = my - bore_area * center.1 * h
      mz = mz - bore_area * h * h / 2.0
    }
    None => ()
  }
  if volume <= CAD_DEGENERATE_EPS {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx / volume, my / volume, mz / volume))
}
