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
/// `backlash_mm` is the circumferential backlash at the pitch circle; it shifts
/// the tooth flanks apart, so two gears at the standard centre distance have a
/// small clearance. Use 0 for the nominal basic profile.
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
