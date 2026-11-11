///|
/// InvoluteGearGeometry is the dimensional description of an external
/// involute gear at one module and tooth count.
pub(all) struct InvoluteGearGeometry {
  module_mm : Double
  teeth : Int32
  pressure_angle_deg : Double
  pitch_radius_mm : Double
  base_radius_mm : Double
  root_radius_mm : Double
  outer_radius_mm : Double
}

///|
/// involute_gear_geometry computes the standard radii for an external involute
/// gear:
///
/// ```text
/// pitch radius = module * teeth / 2
/// base radius  = pitch radius * cos(pressure angle)
/// root radius  = pitch radius - 1.25 * module
/// outer radius = pitch radius + module
/// ```
pub fn involute_gear_geometry(
  module_mm : Double,
  teeth : Int32,
  pressure_angle_deg : Double,
) -> InvoluteGearGeometry {
  let pitch = module_mm * teeth.to_double() / 2.0
  let pa = pressure_angle_deg * @math.PI / 180.0
  {
    module_mm,
    teeth,
    pressure_angle_deg,
    pitch_radius_mm: pitch,
    base_radius_mm: pitch * @math.cos(pa),
    root_radius_mm: pitch - 1.25 * module_mm,
    outer_radius_mm: pitch + module_mm,
  }
}

///|
fn rotate_xy(pt : @cad.Vec2, theta : Double) -> @cad.Vec2 {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (c * pt.0 - s * pt.1, s * pt.0 + c * pt.1)
}

///|
fn involute_xy(radius : Double, theta : Double) -> @cad.Vec2 {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (radius * (c + theta * s), radius * (s - theta * c))
}

///|
fn involute_theta(radius : Double, distance : Double) -> Double {
  let x = distance / radius
  Double::sqrt(x * x - 1.0)
}

///|
fn sq_dist(a : @cad.Vec2, b : @cad.Vec2) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  dx * dx + dy * dy
}

///|
/// clean_polygon removes consecutive points closer than `eps2` (squared
/// distance) and a duplicated seam point.
fn clean_polygon(pts : Array[@cad.Vec2], eps2 : Double) -> Array[@cad.Vec2] {
  let out : Array[@cad.Vec2] = []
  for pt in pts {
    let keep = out.length() == 0 || sq_dist(out[out.length() - 1], pt) > eps2
    if keep {
      out.push(pt)
    }
  }
  while out.length() > 1 && sq_dist(out[0], out[out.length() - 1]) <= eps2 {
    let _ = out.pop()
  }
  out
}

///|
/// external_involute_outline returns a complete external involute gear boundary
/// in the XY plane with one tooth centred on +X.
///
/// `backlash_mm` is a **per-gear** tooth-thickness reduction at the pitch
/// circle; it shifts each flank by `backlash_mm / 2`. A mesh of two gears built
/// with the same value therefore has `2 * backlash_mm` of total circumferential
/// clearance. Use 0 for the nominal basic profile.
///
/// `involute_points` controls the points along each involute flank and
/// `arc_points` controls the tip and root arcs. The result is a closed polygon
/// suitable for an `ExtrudedProfile`.
pub fn external_involute_outline(
  module_mm : Double,
  teeth : Int32,
  pressure_angle_deg : Double,
  backlash_mm~ : Double = 0.0,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
) -> Array[@cad.Vec2] {
  let geom = involute_gear_geometry(module_mm, teeth, pressure_angle_deg)
  let n = teeth.to_double()
  let rb = geom.base_radius_mm
  let rp = geom.pitch_radius_mm
  let rr = geom.root_radius_mm
  let ra = geom.outer_radius_mm
  let inv_points = if involute_points < 2 { 2 } else { involute_points }
  let arcs = if arc_points < 2 { 2 } else { arc_points }
  let two_pi = 2.0 * @math.PI
  let backlash_angle = backlash_mm / (2.0 * rp)
  let pitch_point = involute_xy(rb, involute_theta(rb, rp))
  let face_angle = @math.atan2(pitch_point.1, pitch_point.0)
  let center_angle = @math.PI / (2.0 * n) + face_angle - backlash_angle
  let start_angle = involute_theta(rb, if rr > rb { rr } else { rb })
  let stop_angle = involute_theta(rb, ra)
  let d_theta = (stop_angle - start_angle) / inv_points.to_double()

  let inv : Array[@cad.Vec2] = []
  if rr < rb {
    inv.push(rotate_xy((rr, 0.0), -center_angle))
  }
  let mut angle = start_angle
  for _i in 0..<(inv_points + 1) {
    inv.push(rotate_xy(involute_xy(rb, angle), -center_angle))
    angle = angle + d_theta
  }
  let num_facets = inv.length()

  let arc_tip = inv[num_facets - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<arcs {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / arcs.to_double()
    inv.push(rotate_xy((ra, 0.0), phi))
  }
  for i in 1..<=num_facets {
    let pt = inv[num_facets - i]
    inv.push((pt.0, -pt.1))
  }

  let first_angle = @math.atan2(inv[0].1, inv[0].0)
  let last_angle = @math.atan2(inv[inv.length() - 1].1, inv[inv.length() - 1].0)
  let involute_arc_angle = Double::abs(last_angle - first_angle)
  let gap_arc_angle = two_pi / n - involute_arc_angle
  let gap_delta = gap_arc_angle / arcs.to_double()

  let outline : Array[@cad.Vec2] = []
  let num_inv = inv.length()
  for i in 0..<teeth {
    let theta = -i.to_double() * two_pi / n
    for k in 0..<num_inv {
      outline.push(rotate_xy(inv[num_inv - 1 - k], theta))
    }
    let lower_root = rotate_xy(inv[0], theta)
    for j in 1..<arcs {
      outline.push(rotate_xy(lower_root, -j.to_double() * gap_delta))
    }
  }
  clean_polygon(outline, 1.0e-8)
}

///|
/// involute_outline_area returns the polygon area of a generated outline, useful
/// as a deterministic geometry sanity check.
pub fn involute_outline_area(outline : Array[@cad.Vec2]) -> Double {
  @cad.polygon_area_2d(outline)
}

///|
fn outline_radius(p : @cad.Vec2) -> Double {
  Double::sqrt(p.0 * p.0 + p.1 * p.1)
}

///|
/// outline_indices_at_radius returns the indices of the outline points whose
/// distance from the origin equals `radius` within `tol`.
fn outline_indices_at_radius(
  pts : Array[@cad.Vec2],
  radius : Double,
  tol : Double,
) -> Array[Int32] {
  let out : Array[Int32] = []
  for i, p in pts {
    if (outline_radius(p) - radius).abs() <= tol {
      out.push(i)
    }
  }
  out
}

///|
/// outline_indices_at_most_radius returns the indices of the outline points at
/// or below `radius + tol`.
fn outline_indices_at_most_radius(
  pts : Array[@cad.Vec2],
  radius : Double,
  tol : Double,
) -> Array[Int32] {
  let out : Array[Int32] = []
  for i, p in pts {
    if outline_radius(p) <= radius + tol {
      out.push(i)
    }
  }
  out
}

///|
/// keep_root_endpoints collapses every contiguous run of vertices at or below
/// `root_radius + band` to its two endpoints, so a tangent root fillet has the
/// whole root gap (and a little of the flank) to consume.
///
/// For a high tooth count the root radius is very close to the base radius, so
/// the radial flank segment between them is shorter than a realistic fillet.
/// Including a band equal to the fillet radius lets the fillet reach up the
/// involute flank instead of being rejected by a tiny edge.
fn keep_root_endpoints(
  pts : Array[@cad.Vec2],
  root_radius : Double,
  band : Double,
  tol : Double,
) -> Array[@cad.Vec2] {
  // If every vertex is inside the band there is no run boundary to collapse.
  let mut any_above = false
  for p in pts {
    if outline_radius(p) > root_radius + band + tol {
      any_above = true
      break
    }
  }
  if !any_above {
    return pts
  }
  keep_run_endpoints(pts, root_radius + band, tol)
}

///|
/// keep_tip_endpoints removes the interior points of each tip-arc run, leaving
/// the two tooth tip corners. A tip chamfer bevels those corners; chamfering
/// every sampled tip-arc vertex would be meaningless.
fn keep_tip_endpoints(
  pts : Array[@cad.Vec2],
  tip_radius : Double,
  tol : Double,
) -> Array[@cad.Vec2] {
  let n = pts.length()
  let out : Array[@cad.Vec2] = []
  for i in 0..<n {
    let on_run = (outline_radius(pts[i]) - tip_radius).abs() <= tol
    if on_run {
      let prev = pts[(i + n - 1) % n]
      let next = pts[(i + 1) % n]
      let prev_on = (outline_radius(prev) - tip_radius).abs() <= tol
      let next_on = (outline_radius(next) - tip_radius).abs() <= tol
      if prev_on && next_on {
        // An interior point of the tip-arc run; drop it.
        continue
      }
    }
    out.push(pts[i])
  }
  out
}

///|
/// keep_run_endpoints keeps only the endpoints of each contiguous run of
/// vertices whose radius is at most `threshold`.
fn keep_run_endpoints(
  pts : Array[@cad.Vec2],
  threshold : Double,
  tol : Double,
) -> Array[@cad.Vec2] {
  let n = pts.length()
  let out : Array[@cad.Vec2] = []
  for i in 0..<n {
    let on_run = outline_radius(pts[i]) <= threshold + tol
    if on_run {
      let prev = pts[(i + n - 1) % n]
      let next = pts[(i + 1) % n]
      let prev_on = outline_radius(prev) <= threshold + tol
      let next_on = outline_radius(next) <= threshold + tol
      if prev_on && next_on {
        // An interior point of the run; drop it.
        continue
      }
    }
    out.push(pts[i])
  }
  out
}

///|
/// external_involute_outline_ex is `external_involute_outline` with optional
/// root fillets and tip chamfers applied to the true involute boundary.
///
/// `root_fillet_radius_mm` rounds the re-entrant root corners (material is
/// added at the root), and `tip_chamfer_mm` bevels the tip vertices (material
/// is removed at the tip). Both use the kernel's 2D profile operations, so the
/// result is a simple polygon. The arc is sampled with `fillet_segments`
/// points; the chord deviation is reported by `gear_outline_deviation_mm`.
///
/// A rejected operation (feature too large for the adjacent edges, or a
/// self-intersection) is returned as a typed `SpecError`; the outline is never
/// silently returned unmodified.
pub fn external_involute_outline_ex(
  module_mm : Double,
  teeth : Int32,
  pressure_angle_deg : Double,
  backlash_mm~ : Double = 0.0,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
  root_fillet_radius_mm~ : Double = 0.0,
  tip_chamfer_mm~ : Double = 0.0,
  fillet_segments~ : Int32 = 4,
) -> Result[Array[@cad.Vec2], @common.SpecError] {
  if !(root_fillet_radius_mm >= 0.0) || !(tip_chamfer_mm >= 0.0) {
    return Err(
      @common.InvalidParameter(
        "gear root fillet radius and tip chamfer must be non-negative and finite",
      ),
    )
  }
  let geom = involute_gear_geometry(module_mm, teeth, pressure_angle_deg)
  let tol = 1.0e-6 * (1.0 + geom.outer_radius_mm)
  let mut pts = external_involute_outline(
    module_mm,
    teeth,
    pressure_angle_deg,
    backlash_mm~,
    involute_points~,
    arc_points~,
  )
  if tip_chamfer_mm > 0.0 {
    let tip_pts = keep_tip_endpoints(pts, geom.outer_radius_mm, tol)
    let indices = outline_indices_at_radius(tip_pts, geom.outer_radius_mm, tol)
    if indices.is_empty() {
      return Err(
        @common.InvalidParameter("gear tip chamfer found no tip vertices"),
      )
    }
    pts = match
      @cad.Profile2D::chamfer_vertices(
        tip_pts,
        tip_chamfer_mm,
        which=@cad.VertexSelection::Indices(indices),
      ) {
      Ok(p) => p
      Err(e) =>
        return Err(
          @common.InvalidParameter("gear tip chamfer rejected: " + e.message()),
        )
    }
  }
  if root_fillet_radius_mm > 0.0 {
    let max_band = 0.5 * (geom.outer_radius_mm - geom.root_radius_mm)
    let mut band = root_fillet_radius_mm
    let mut result : Array[@cad.Vec2]? = None
    let mut last_error = ""
    while band <= max_band {
      let root_pts = keep_root_endpoints(pts, geom.root_radius_mm, band, tol)
      let indices = outline_indices_at_most_radius(
        root_pts,
        geom.root_radius_mm + band,
        tol,
      )
      if !indices.is_empty() {
        match
          @cad.Profile2D::fillet_vertices(
            root_pts,
            root_fillet_radius_mm,
            segments=fillet_segments,
            which=@cad.VertexSelection::Indices(indices),
          ) {
          Ok(p) => {
            result = Some(p)
            break
          }
          Err(e) => last_error = e.message()
        }
      }
      band = band * 1.5
    }
    match result {
      Some(p) => pts = p
      None =>
        return Err(
          @common.InvalidParameter("gear root fillet rejected: " + last_error),
        )
    }
  }
  Ok(pts)
}

///|
/// gear_outline_deviation_mm returns the chord deviation of a polyline fillet
/// arc sampled with `segments` points.
pub fn gear_outline_deviation_mm(
  radius_mm : Double,
  segments : Int32,
) -> Double {
  @common.chord_deviation(radius_mm, segments)
}

///|
/// gear_outline_min_radius returns the smallest distance from the origin to any
/// outline vertex (the modelled root radius).
pub fn gear_outline_min_radius(outline : Array[@cad.Vec2]) -> Double {
  let mut min_r = 1.0e300
  for p in outline {
    let r = outline_radius(p)
    if r < min_r {
      min_r = r
    }
  }
  min_r
}

///|
/// gear_outline_max_radius returns the largest distance from the origin to any
/// outline vertex (the modelled tip radius).
pub fn gear_outline_max_radius(outline : Array[@cad.Vec2]) -> Double {
  let mut max_r = 0.0
  for p in outline {
    let r = outline_radius(p)
    if r > max_r {
      max_r = r
    }
  }
  max_r
}
