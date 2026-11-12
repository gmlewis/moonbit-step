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
  let eps = 1.0e-9
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
  let eps = 1.0e-9
  // A horizontal boundary at the section plane is a cap: the closure of the
  // solid includes the whole radial interval it spans.
  for seg in segs {
    match seg {
      RevLine(a, b) =>
        if (a.1 - b.1).abs() < eps && (z0 - a.1).abs() < 1.0e-7 {
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
        if disc > 1.0e-14 {
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
  let unique = an_sort_unique(crossings, 1.0e-7)
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
        if dz.abs() < 1.0e-9 {
          // A horizontal band is a cap: it lies in the section plane only when
          // z0 equals that plane.
          if (z0 - a.1).abs() < 1.0e-7 {
            radii.push(a.0)
            radii.push(b.0)
          }
        } else {
          let t = (z0 - a.1) / dz
          if t >= -1.0e-9 && t <= 1.0 + 1.0e-9 {
            radii.push(a.0 + t * (b.0 - a.0))
          }
        }
      }
      RevArc(a, b, c) => {
        let rho = rev_dist2(a, c)
        let dzc = z0 - c.1
        let disc = rho * rho - dzc * dzc
        if disc > 1.0e-14 {
          let dr = Double::sqrt(disc)
          for cand in [c.0 + dr, c.0 - dr] {
            if cand >= -1.0e-9 && an_arc_contains(c, a, b, cand, z0) {
              radii.push(cand)
            }
          }
        }
        // A tangent plane (disc ~ 0) touches the arc at one point; it bounds
        // no material, so it contributes no section ring.
      }
    }
  }
  let candidates = an_sort_unique(radii, 1.0e-7)
  let intervals : Array[(Double, Double)] = []
  let mut i = 0
  while i + 1 < candidates.length() {
    let ri = candidates[i]
    let ro = candidates[i + 1]
    if ro - ri > 1.0e-9 {
      let mid = (ri + ro) / 2.0
      if an_rev_contains(segs, z0, mid) {
        if intervals.length() > 0 {
          let prev = intervals[intervals.length() - 1]
          if ri <= prev.1 + 1.0e-7 {
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
  if rings.length() == 0 || area <= 1.0e-12 {
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
  let zc = if i2.abs() < 1.0e-12 { 0.0 } else { iz / i2 }
  (volume, zc)
}

///|
fn an_lerp_inset(levels : Array[(Double, Double)], z : Double) -> Double? {
  let n = levels.length()
  if n == 0 {
    return None
  }
  if z < levels[0].0 - 1.0e-9 || z > levels[n - 1].0 + 1.0e-9 {
    return None
  }
  if n == 1 {
    return Some(levels[0].1)
  }
  for i in 0..<(n - 1) {
    let (z0, v0) = levels[i]
    let (z1, v1) = levels[i + 1]
    if z >= z0 - 1.0e-9 && z <= z1 + 1.0e-9 {
      if (z1 - z0).abs() < 1.0e-12 {
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
  if area <= 1.0e-12 {
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
  an_sort_unique(zs, 1.0e-9)
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
  if volume <= 1.0e-12 {
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
      let phi = Double::from_int(i) * (@math.PI / 2.0) / Double::from_int(segs)
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
  if volume <= 1.0e-12 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx_total / volume, my_total / volume, mz_total / volume))
}

///|
/// an_extruded_props computes the exact section area, perimeter and signed
/// first moments of an extruded profile.
fn an_extruded_props(
  extrusion : ExtrudedProfile,
) -> (Double, Double, Double, Double, Double, Double, Array[SectionRing]) {
  let profile = extrusion.profile
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
  match extrusion.round_bore {
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
  if z < -1.0e-9 || z > extrusion.height_mm + 1.0e-9 {
    return Err(EmptySection)
  }
  if extrusion.height_mm <= 0.0 || extrusion.profile.outer.length() < 3 {
    return Err(DegenerateProfile)
  }
  let (area, perimeter, _mx, _my, outer, inner, rings) = an_extruded_props(
    extrusion,
  )
  if area <= 1.0e-12 {
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
  if area <= 1.0e-12 {
    return (0.0, (0.0, 0.0, 0.0))
  }
  (volume, (mx / area, my / area, extrusion.height_mm / 2.0))
}

///|
fn an_bezier_group_is_curved(group : Array[BezierPath]) -> Bool {
  for path in group {
    if path_has_curved_span(path) {
      return true
    }
  }
  false
}

///|
fn an_bezier_contour_ok(path : BezierPath) -> Bool {
  bspline_control_points(path).length() >= 4
}

///|
fn an_bezier_inventory(e : ExtrudedBezierProfile) -> SurfaceInventory {
  let mut planes = 0
  let mut swept = 0
  if e.height_mm == 0.0 {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  for group in bezier_path_groups(e.paths) {
    if group.is_empty() {
      continue
    }
    if an_bezier_group_is_curved(group) {
      if !an_bezier_contour_ok(group[0]) {
        continue
      }
      planes = planes + 2
      swept = swept + 1
      for i in 1..<group.length() {
        if an_bezier_contour_ok(group[i]) {
          swept = swept + 1
        }
      }
    } else {
      let profile = flatten_group_profile(group)
      if profile.outer.length() < 3 {
        continue
      }
      planes = planes + 2 + profile.outer.length()
      for h in profile.holes {
        if h.length() >= 3 {
          planes = planes + h.length()
        }
      }
    }
  }
  an_inventory(planes, 0, 0, 0, 0, 0, swept, 0)
}

///|
/// an_swept_inventory mirrors the swept-profile compiler's planar triangulation.
fn an_swept_inventory(s : SweptProfile) -> SurfaceInventory {
  let path = s.path
  let profile = s.profile
  let num_path_pts = path.points.length()
  if num_path_pts < 2 || profile.vertices.length() < 3 {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  let loops : Array[Array[Vec3]] = [
    profile.vertices,
    ..profile.holes.filter(fn(h) { h.length() >= 3 }),
  ]
  let prof_z = v_norm(profile.normal_dir)
  let prof_x = v_norm(profile.right_dir)
  let prof_y = v_cross(prof_z, prof_x)
  let m_global_to_prof = Matrix3x3::{
    m00: prof_x.0,
    m01: prof_x.1,
    m02: prof_x.2,
    m10: prof_y.0,
    m11: prof_y.1,
    m12: prof_y.2,
    m20: prof_z.0,
    m21: prof_z.1,
    m22: prof_z.2,
  }
  let local_loops = loops.map(fn(lp) {
    lp.map(fn(v) { apply_matrix(m_global_to_prof, v_sub(v, profile.center)) })
  })
  let local_verts : Array[Vec3] = []
  let is_hole : Array[Bool] = []
  let loop_offsets : Array[Int32] = []
  let mut loop_index = 0
  for lp in local_loops {
    loop_offsets.push(local_verts.length())
    for v in lp {
      local_verts.push(v)
      is_hole.push(loop_index > 0)
    }
    loop_index = loop_index + 1
  }
  let t0 = v_norm(path.tangents[0])
  let n0 = v_norm(path.normals[0])
  let r0 = v_norm(v_cross(t0, n0))
  let m_start_to_global = Matrix3x3::{
    m00: r0.0,
    m01: n0.0,
    m02: t0.0,
    m10: r0.1,
    m11: n0.1,
    m12: t0.1,
    m20: r0.2,
    m21: n0.2,
    m22: t0.2,
  }
  let pts : Array[Vec3] = []
  for i in 0..<num_path_pts {
    let p_origin = path.points[i]
    let p_tangent = v_norm(path.tangents[i])
    let p_normal = v_norm(path.normals[i])
    let p_right = v_norm(v_cross(p_tangent, p_normal))
    let m_path_to_global = Matrix3x3::{
      m00: p_right.0,
      m01: p_normal.0,
      m02: p_tangent.0,
      m10: p_right.1,
      m11: p_normal.1,
      m12: p_tangent.1,
      m20: p_right.2,
      m21: p_normal.2,
      m22: p_tangent.2,
    }
    for j, v in local_verts {
      let keep_straight = if is_hole[j] {
        s.straight_holes
      } else {
        s.straight_outline
      }
      let gv = if keep_straight {
        apply_matrix(m_start_to_global, v)
      } else {
        apply_matrix(m_path_to_global, v)
      }
      pts.push((gv.0 + p_origin.0, gv.1 + p_origin.1, gv.2 + p_origin.2))
    }
  }
  let num_prof_verts = local_verts.length()
  let mut planes = 0
  for i in 0..<(num_path_pts - 1) {
    let offset1 = i * num_prof_verts
    let offset2 = (i + 1) * num_prof_verts
    for li in 0..<local_loops.length() {
      let lo = loop_offsets[li]
      let n = local_loops[li].length()
      for j in 0..<n {
        let k = (j + 1) % n
        let b1 = offset1 + lo + j
        let b2 = offset1 + lo + k
        let t1 = offset2 + lo + j
        let t2 = offset2 + lo + k
        let p0 = pts[b1]
        let p1 = pts[b2]
        let p2 = pts[t1]
        let p3 = pts[t2]
        let expected = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
        let off = Double::abs(v_dot(v_sub(p3, p0), expected))
        if off <= 1.0e-6 {
          planes = planes + 1
        } else {
          planes = planes + 2
        }
      }
    }
  }
  if s.make_start_cap {
    planes = planes + 1
  }
  if s.make_end_cap {
    planes = planes + 1
  }
  an_inventory(planes, 0, 0, 0, 0, 0, 0, 0)
}

///|
/// an_shape_inventory mirrors the compiler's face-emission rules.
fn an_shape_inventory(shape : Shape) -> SurfaceInventory {
  match shape {
    Cuboid(_) => an_inventory(6, 0, 0, 0, 0, 0, 0, 0)
    Cylinder(c) =>
      if c.diameter / 2.0 > 0.0 && c.height > 0.0 {
        an_inventory(2, 1, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    RevolvedProfile(rev) => {
      match rev.validate() {
        Err(_) => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
        Ok(_) => ()
      }
      let mut p = 0
      let mut cy = 0
      let mut co = 0
      let mut sp = 0
      let mut to = 0
      for seg in rev.segments {
        let (a, b, center) = match seg {
          RevLine(a, b) => (a, b, None)
          RevArc(a, b, c) => (a, b, Some(c))
        }
        let has_a = a.0 > 1.0e-9
        let has_b = b.0 > 1.0e-9
        if !(has_a || has_b) {
          continue
        }
        match center {
          Some(c) => if c.0.abs() < 1.0e-9 { sp = sp + 1 } else { to = to + 1 }
          None => {
            let radial = (a.1 - b.1).abs() < 1.0e-9
            let axial = (a.0 - b.0).abs() < 1.0e-9
            if radial {
              p = p + 1
            } else if axial {
              cy = cy + 1
            } else {
              co = co + 1
            }
          }
        }
      }
      an_inventory(p, cy, co, sp, to, 0, 0, 0)
    }
    ChamferedPrism(p) => an_prism_inventory(p)
    SocketedSolid(s) => an_socketed_inventory(s)
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let lead_cones = if g.lead > 0.0 { 2 } else { 0 }
          an_inventory(8, 1, 12 + lead_cones, 0, 0, 0, 0, 0)
        }
        None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    SlitTube(t) => an_slit_tube_inventory(t)
    AcornNut(n) => an_acorn_nut_inventory(n)
    CalibrationChamferBlock(b) => {
      let rings = an_calib_rings(b)
      let n = rings.length()
      if n >= 2 {
        an_inventory(2 + 4 * (n - 1), 0, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    }
    ExtrudedProfile(e) => {
      if e.height_mm == 0.0 || e.profile.outer.length() < 3 {
        return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
      let outer_n = e.profile.outer.length()
      let mut hole_n = 0
      for h in e.profile.holes {
        if h.length() >= 3 {
          hole_n = hole_n + h.length()
        }
      }
      let cylinder = match e.round_bore {
        Some((_center, diameter)) => if diameter > 0.0 { 1 } else { 0 }
        None => 0
      }
      an_inventory(2 + outer_n + hole_n, cylinder, 0, 0, 0, 0, 0, 0)
    }
    ExtrudedArcProfile(e) => an_extruded_arc_inventory(e)
    SquareHoleWasher(w) => an_square_hole_inventory(w)
    TabWasher(w) => an_tab_inventory(w)
    // Six planar flats, the flat underside, and the circular top: eight planes.
    // The chamfer is six CONICAL_SURFACE patches, not cylinders. The unified
    // shank variant adds the underside annulus, washer face, tip disk and
    // shank/land cylinders.
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let washer = h.washer_face_diameter_mm > 0.0 &&
          h.washer_face_height_mm > 0.0
        let tip_cone = h.tip_chamfer_mm > 0.0 &&
          h.tip_chamfer_mm < h.shank_diameter_mm / 2.0
        an_inventory(
          9 + (if washer { 1 } else { 0 }),
          1 + (if washer { 1 } else { 0 }),
          6 + (if tip_cone { 1 } else { 0 }),
          0,
          0,
          0,
          0,
          0,
        )
      } else {
        an_inventory(8, 0, 6, 0, 0, 0, 0, 0)
      }
    ExtrudedBezierProfile(e) => an_bezier_inventory(e)
    SweptProfile(s) => an_swept_inventory(s)
    Fillet(f) => an_shape_inventory(f.base.shape)
    Chamfer(c) => an_shape_inventory(c.base.shape)
    Union(u) => {
      let mut inv = an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      for child in u.nodes {
        inv = inv.add(an_shape_inventory(child.shape))
      }
      inv
    }
    Difference(d) => {
      let mut inv = an_shape_inventory(d.base.shape)
      for cutter in d.cutters {
        inv = inv.add(an_shape_inventory(cutter.shape))
      }
      inv
    }
  }
}

///|
fn an_prism_inventory(p : ChamferedPrism) -> SurfaceInventory {
  match p.validate() {
    Err(_) => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
    Ok(_) => ()
  }
  let nc = p.base.length()
  let nl = p.levels.length()
  match p.round_bore {
    Some((_center, diameter)) =>
      if diameter > 0.0 {
        an_inventory(2 + (nl - 1) * nc, 1, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(2 + (nl - 1) * nc, 0, 0, 0, 0, 0, 0, 0)
      }
    None => {
      let mut planes = 2 + (nl - 1) * nc
      match p.hole {
        Some(h) =>
          match p.hole_levels {
            Some(hls) => planes = planes + (hls.length() - 1) * h.length()
            None => planes = planes + h.length()
          }
        None => ()
      }
      an_inventory(planes, 0, 0, 0, 0, 0, 0, 0)
    }
  }
}

///|
/// an_socketed_inventory mirrors the `compile_socketed_solid` face emission: the
/// body's analytic revolve faces minus its flat top cap, plus the annular top
/// face, six socket walls, the optional six ruled lead-in faces, and the floor.
fn an_socketed_inventory(s : SocketedSolid) -> SurfaceInventory {
  let base = an_shape_inventory(Shape::RevolvedProfile(s.body))
  if s.conical {
    // The top cap is replaced by the annular top face and six flat planes; the
    // rim and drill cones are one surface entity each (shared by their
    // patches), giving the detailed reference's plane 9 / cone 5 / cylinder 2.
    return an_inventory(
      base.plane - 1 + 7,
      base.cylinder,
      base.cone + 2,
      base.sphere,
      base.torus,
      base.bspline,
      base.swept,
      base.other,
    )
  }
  let g = match socketed_geometry(s) {
    Some(v) => v
    None => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  let lead_faces = if g.lead > CAD_DEGENERATE_EPS { 6 } else { 0 }
  an_inventory(
    base.plane - 1 + 8 + lead_faces,
    base.cylinder,
    base.cone,
    base.sphere,
    base.torus,
    base.bspline,
    base.swept,
    base.other,
  )
}

///|
/// Shape::surface_inventory returns the analytic face counts the compiler
/// emits for this shape.
pub fn Shape::surface_inventory(self : Shape) -> SurfaceInventory {
  an_shape_inventory(self)
}

///|
/// Shape::analysis_volume returns the exact volume in mm^3, or a typed error
/// when the shape is not analytically analyzable.
pub fn Shape::analysis_volume(self : Shape) -> Result[Double, AnalysisError] {
  match self {
    Cuboid(c) => Ok(c.sx * c.sy * c.sz)
    Cylinder(c) =>
      Ok(@math.PI * (c.diameter / 2.0) * (c.diameter / 2.0) * c.height)
    RevolvedProfile(rev) => {
      let (volume, _zc) = an_rev_volume_centroid(rev)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ChamferedPrism(p) => {
      let (volume, _c) = an_prism_volume_centroid(p)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    SocketedSolid(s) => {
      let volume = s.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let (volume, _zc) = conical_nut_volume_centroid(g)
          if volume <= 0.0 {
            Err(DegenerateProfile)
          } else {
            Ok(volume)
          }
        }
        None => Err(DegenerateProfile)
      }
    SlitTube(t) => {
      let volume = t.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    AcornNut(n) => {
      let volume = n.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    CalibrationChamferBlock(b) => {
      let (volume, _c) = an_calib_volume_centroid(b)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ExtrudedProfile(e) => {
      let (volume, _c) = an_extruded_volume_centroid(e)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ExtrudedArcProfile(e) => {
      let volume = e.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    SquareHoleWasher(w) => {
      let volume = shw_area(w) * w.thickness_mm
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    TabWasher(w) => {
      let (material, _c) = tw_area_centroid(w)
      let volume = material * w.thickness_mm
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let (volume, _c) = hhwf_screw_volume_centroid(h)
        if volume <= 0.0 {
          Err(DegenerateProfile)
        } else {
          Ok(volume)
        }
      } else {
        match hhwf_proxy(h) {
          Some(p) => {
            let volume = p.volume()
            if volume <= 0.0 {
              Err(DegenerateProfile)
            } else {
              Ok(volume)
            }
          }
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(u) => {
      let mut volume = 0.0
      for child in u.nodes {
        match child.shape.analysis_volume() {
          Ok(v) => volume = volume + v
          Err(e) => return Err(e)
        }
      }
      Ok(volume)
    }
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
  }
}

///|
/// Shape::analysis_centroid returns the exact centroid in the shape's local
/// frame, or a typed error when it is not analytically known.
pub fn Shape::analysis_centroid(self : Shape) -> Result[Vec3, AnalysisError] {
  match self {
    Cuboid(c) => Ok((c.sx / 2.0, c.sy / 2.0, c.sz / 2.0))
    Cylinder(c) => Ok((0.0, 0.0, c.height / 2.0))
    RevolvedProfile(rev) => {
      let (_volume, zc) = an_rev_volume_centroid(rev)
      Ok((0.0, 0.0, zc))
    }
    ChamferedPrism(p) => {
      let (_volume, c) = an_prism_volume_centroid(p)
      Ok(c)
    }
    SocketedSolid(s) => Ok(s.centroid())
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let (_volume, zc) = conical_nut_volume_centroid(g)
          Ok((0.0, 0.0, zc))
        }
        None => Err(DegenerateProfile)
      }
    SlitTube(t) => Ok(t.centroid())
    AcornNut(n) => Ok(n.centroid())
    CalibrationChamferBlock(b) => {
      let (_volume, c) = an_calib_volume_centroid(b)
      Ok(c)
    }
    ExtrudedProfile(e) => {
      let (_volume, c) = an_extruded_volume_centroid(e)
      Ok(c)
    }
    ExtrudedArcProfile(e) => Ok(e.centroid())
    SquareHoleWasher(w) => Ok((0.0, 0.0, w.thickness_mm / 2.0))
    TabWasher(w) => {
      let (_material, c) = tw_area_centroid(w)
      Ok((c.0, c.1, w.thickness_mm / 2.0))
    }
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let (_volume, zc) = hhwf_screw_volume_centroid(h)
        Ok((0.0, 0.0, zc))
      } else {
        match hhwf_proxy(h) {
          Some(p) => {
            let (_volume, c) = an_prism_volume_centroid(p)
            Ok(c)
          }
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(u) => {
      let mut volume = 0.0
      let mut mx = 0.0
      let mut my = 0.0
      let mut mz = 0.0
      for child in u.nodes {
        let v = match child.shape.analysis_volume() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let c = match child.shape.analysis_centroid() {
          Ok(c) => c
          Err(e) => return Err(e)
        }
        let (rx, ry, rz) = rotate_point(c, child.rx, child.ry, child.rz)
        volume = volume + v
        mx = mx + v * (rx + child.tx)
        my = my + v * (ry + child.ty)
        mz = mz + v * (rz + child.tz)
      }
      if volume <= 1.0e-12 {
        Err(DegenerateProfile)
      } else {
        Ok((mx / volume, my / volume, mz / volume))
      }
    }
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
  }
}

///|
/// Shape::section_at_local returns the exact horizontal cross-section at local
/// `z`.
pub fn Shape::section_at_local(
  self : Shape,
  z : Double,
) -> Result[Section, AnalysisError] {
  match self {
    Cuboid(c) => {
      if z < -1.0e-9 || z > c.sz + 1.0e-9 {
        return Err(EmptySection)
      }
      let area = c.sx * c.sy
      if area <= 1.0e-12 {
        return Err(DegenerateProfile)
      }
      let outer = Double::sqrt(c.sx * c.sx + c.sy * c.sy)
      Ok({
        z_mm: z,
        area_mm2: area,
        perimeter_mm: 2.0 * (c.sx + c.sy),
        outer_radius_mm: outer,
        inner_radius_mm: 0.0,
        rings: [{ inner_radius_mm: 0.0, outer_radius_mm: outer, }],
      })
    }
    Cylinder(c) => Cylinder::section_at(c, z)
    RevolvedProfile(rev) => rev.section_at(z)
    ChamferedPrism(p) => p.section_at(z)
    SocketedSolid(s) => an_socketed_section(s, z)
    ConicalNut(n) => an_conical_nut_section(n, z)
    AcornNut(n) => an_acorn_nut_section(n, z)
    SlitTube(t) => an_slit_tube_section(t, z)
    CalibrationChamferBlock(b) => an_calib_section(b, z)
    ExtrudedProfile(e) => e.section_at(z)
    ExtrudedArcProfile(e) => an_extruded_arc_section(e, z)
    SquareHoleWasher(w) => an_square_hole_section(w, z)
    TabWasher(w) => an_tab_section(w, z)
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let area = hhwf_screw_area(h, z)
        if area <= CAD_AREA_EPS {
          Err(EmptySection)
        } else {
          let outer = Double::sqrt(area / @math.PI)
          Ok({
            z_mm: z,
            area_mm2: area,
            perimeter_mm: hhwf_screw_perimeter(h, z),
            outer_radius_mm: outer,
            inner_radius_mm: 0.0,
            rings: [{ inner_radius_mm: 0.0, outer_radius_mm: outer, }],
          })
        }
      } else {
        match hhwf_proxy(h) {
          Some(p) => p.section_at(z)
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(_) => Err(NotAnalytic("union sections are reported per child"))
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
  }
}

///|
/// Cylinder::section_at returns the exact disc section at local `z`.
pub fn Cylinder::section_at(
  self : Cylinder,
  z : Double,
) -> Result[Section, AnalysisError] {
  let r = self.diameter / 2.0
  if r <= 0.0 || self.height <= 0.0 {
    return Err(DegenerateProfile)
  }
  if z < -1.0e-9 || z > self.height + 1.0e-9 {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: @math.PI * r * r,
    perimeter_mm: 2.0 * @math.PI * r,
    outer_radius_mm: r,
    inner_radius_mm: 0.0,
    rings: [{ inner_radius_mm: 0.0, outer_radius_mm: r, }],
  })
}

///|
/// Cylinder::volume returns the exact cylinder volume.
pub fn Cylinder::volume(self : Cylinder) -> Double {
  let r = self.diameter / 2.0
  @math.PI * r * r * self.height
}

///|
/// RevolvedProfile::section_at returns the exact section at local `z`.
pub fn RevolvedProfile::section_at(
  self : RevolvedProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_rev_section(self, z)
}

///|
/// RevolvedProfile::volume returns the exact volume.
pub fn RevolvedProfile::volume(self : RevolvedProfile) -> Double {
  let (volume, _zc) = an_rev_volume_centroid(self)
  volume
}

///|
/// RevolvedProfile::centroid returns the exact centroid.
pub fn RevolvedProfile::centroid(self : RevolvedProfile) -> Vec3 {
  let (_volume, zc) = an_rev_volume_centroid(self)
  (0.0, 0.0, zc)
}

///|
/// ExtrudedProfile::section_at returns the exact extruded section at local
/// `z`.
pub fn ExtrudedProfile::section_at(
  self : ExtrudedProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_extruded_section(self, z)
}

///|
/// ExtrudedProfile::volume returns the exact extruded volume.
pub fn ExtrudedProfile::volume(self : ExtrudedProfile) -> Double {
  let (volume, _c) = an_extruded_volume_centroid(self)
  volume
}

///|
/// ChamferedPrism::section_at returns the exact prism section at local `z`.
pub fn ChamferedPrism::section_at(
  self : ChamferedPrism,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_prism_section(self, z)
}

///|
/// ChamferedPrism::volume returns the exact prism volume.
pub fn ChamferedPrism::volume(self : ChamferedPrism) -> Double {
  let (volume, _c) = an_prism_volume_centroid(self)
  volume
}

///|
/// an_extruded_mesh builds a visualization mesh for an extruded polygon. The
/// caps are fan-triangulated; holes are represented by their side walls. This
/// is an OBJ/visualization helper, not an analytic result.
fn an_extruded_mesh(e : ExtrudedProfile) -> (Array[Vec3], Array[Array[Int32]]) {
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let h = e.height_mm
  let loops : Array[Array[Vec2]] = [
    e.profile.outer,
    ..e.profile.holes.filter(fn(hh) { hh.length() >= 3 }),
  ]
  for lp in loops {
    let n = lp.length()
    if n < 3 {
      continue
    }
    let base = verts.length()
    for p in lp {
      verts.push((p.0, p.1, 0.0))
    }
    for p in lp {
      verts.push((p.0, p.1, h))
    }
    for i in 0..<n {
      let j = (i + 1) % n
      faces.push([base + i, base + j, base + n + j, base + n + i])
    }
    // Fan caps for each loop (outer and holes are independent fans).
    for i in 1..<(n - 1) {
      faces.push([base, base + i + 1, base + i])
      faces.push([base + n, base + n + i, base + n + i + 1])
    }
  }
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let k = 32
      let base = verts.length()
      for i in 0..<k {
        let th = 2.0 * @math.PI * Double::from_int(i) / Double::from_int(k)
        let x = center.0 + rb * @math.cos(th)
        let y = center.1 + rb * @math.sin(th)
        verts.push((x, y, 0.0))
        verts.push((x, y, h))
      }
      for i in 0..<k {
        let j = (i + 1) % k
        faces.push([
          base + 2 * i,
          base + 2 * j,
          base + 2 * j + 1,
          base + 2 * i + 1,
        ])
      }
    }
    None => ()
  }
  (verts, faces)
}

///|
/// Shape::analysis_mesh returns a triangle/quad visualization mesh in the
/// shape's local frame. It is deliberately separate from the analytic API:
/// mesh output is a graphic approximation.
pub fn Shape::analysis_mesh(
  self : Shape,
) -> Result[(Array[Vec3], Array[Array[Int32]]), AnalysisError] {
  match self {
    Cuboid(c) => {
      let (sx, sy, sz) = (c.sx, c.sy, c.sz)
      let verts : Array[Vec3] = [
        (0.0, 0.0, 0.0),
        (sx, 0.0, 0.0),
        (sx, sy, 0.0),
        (0.0, sy, 0.0),
        (0.0, 0.0, sz),
        (sx, 0.0, sz),
        (sx, sy, sz),
        (0.0, sy, sz),
      ]
      let faces : Array[Array[Int32]] = [
        [0, 3, 2, 1],
        [4, 5, 6, 7],
        [0, 1, 5, 4],
        [1, 2, 6, 5],
        [2, 3, 7, 6],
        [3, 0, 4, 7],
      ]
      Ok((verts, faces))
    }
    Cylinder(c) => {
      let r = c.diameter / 2.0
      let h = c.height
      let k = 48
      let verts : Array[Vec3] = []
      for i in 0..<k {
        let th = 2.0 * @math.PI * Double::from_int(i) / Double::from_int(k)
        verts.push((r * @math.cos(th), r * @math.sin(th), 0.0))
      }
      for i in 0..<k {
        let th = 2.0 * @math.PI * Double::from_int(i) / Double::from_int(k)
        verts.push((r * @math.cos(th), r * @math.sin(th), h))
      }
      let faces : Array[Array[Int32]] = []
      for i in 0..<k {
        let j = (i + 1) % k
        faces.push([i, j, k + j, k + i])
      }
      for i in 1..<(k - 1) {
        faces.push([0, i + 1, i])
        faces.push([k, k + i, k + i + 1])
      }
      Ok((verts, faces))
    }
    RevolvedProfile(rev) => Ok(rev_mesh(rev))
    SocketedSolid(s) => Ok(socketed_solid_mesh(s))
    ConicalNut(n) => Ok(conical_nut_mesh(n))
    AcornNut(n) => Ok(acorn_nut_mesh(n))
    SlitTube(t) => Ok(slit_tube_mesh(t))
    ChamferedPrism(p) => Ok(chamfered_prism_mesh(p))
    ExtrudedProfile(e) =>
      if e.height_mm <= 0.0 || e.profile.outer.length() < 3 {
        Err(DegenerateProfile)
      } else {
        Ok(an_extruded_mesh(e))
      }
    ExtrudedArcProfile(e) =>
      if !e.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(extruded_arc_mesh(e))
      }
    SquareHoleWasher(w) =>
      if shw_area(w) <= 0.0 || w.thickness_mm <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(square_hole_mesh(w))
      }
    TabWasher(w) => {
      let (material, _c) = tw_area_centroid(w)
      if material <= 0.0 || w.thickness_mm <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(tab_washer_mesh(w))
      }
    }
    HexHeadWasherFace(h) =>
      match hhwf_proxy(h) {
        Some(p) => Ok(chamfered_prism_mesh(p))
        None => Err(DegenerateProfile)
      }
    Union(u) => {
      let verts : Array[Vec3] = []
      let faces : Array[Array[Int32]] = []
      for child in u.nodes {
        let (cv, cf) = match child.shape.analysis_mesh() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let base = verts.length()
        for v in cv {
          let (rx, ry, rz) = rotate_point(v, child.rx, child.ry, child.rz)
          verts.push((rx + child.tx, ry + child.ty, rz + child.tz))
        }
        for f in cf {
          faces.push(f.map(fn(idx) { idx + base }))
        }
      }
      Ok((verts, faces))
    }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("mesh requires Bezier tessellation"))
    SweptProfile(_) => Err(NotAnalytic("mesh requires sweep tessellation"))
    Fillet(_) => Err(NotAnalytic("mesh requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("mesh requires a trimming kernel"))
    CalibrationChamferBlock(_) =>
      Err(NotAnalytic("mesh is not implemented for the calibration block"))
    Difference(_) => Err(NotAnalytic("nominal difference has no trimmed mesh"))
  }
}

///|
/// Shape::section_at_world_z applies a rigid placement and returns an exact
/// world-z section. Only translations and rotations that preserve +Z are
/// exact; any other rotation returns `UnsupportedTransform` instead of a
/// silently approximate section.
pub fn Shape::section_at_world_z(
  self : Shape,
  rot : Matrix3x3,
  trans : Vec3,
  z : Double,
) -> Result[Section, AnalysisError] {
  let z_preserved = rot.m02.abs() < 1.0e-7 &&
    rot.m12.abs() < 1.0e-7 &&
    (rot.m22 - 1.0).abs() < 1.0e-7
  if !z_preserved {
    return Err(UnsupportedTransform("rotation does not map +Z to +Z"))
  }
  let local_z = z - trans.2
  match self.section_at_local(local_z) {
    Ok(s) =>
      Ok({
        z_mm: z,
        area_mm2: s.area_mm2,
        perimeter_mm: s.perimeter_mm,
        outer_radius_mm: s.outer_radius_mm,
        inner_radius_mm: s.inner_radius_mm,
        rings: s.rings,
      })
    Err(e) => Err(e)
  }
}
