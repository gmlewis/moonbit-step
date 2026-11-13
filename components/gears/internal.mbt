///|
/// InternalRingGeometry is the dimensional description of an exact internal
/// involute ring gear at one module and tooth count.
///
/// An internal (ring) gear differs from an external gear in three ways:
///
/// - its tooth tips point inward, at `pitch - addendum * m`;
/// - its roots reach outward, at `pitch + dedendum * m`;
/// - its tooth thickness grows outward: `psi(r) = psi_p + inv(a_r) - inv(a_p)`.
///
/// The last relation is the sign that a naive reuse of the external formula
/// gets wrong, and it is what makes a generated planet mesh instead of
/// interfering.
pub(all) struct InternalRingGeometry {
  module_mm : Double
  teeth : Int32
  pressure_angle_deg : Double
  pitch_radius_mm : Double
  base_radius_mm : Double
  tip_radius_mm : Double
  root_radius_mm : Double
  addendum_factor : Double
  dedendum_factor : Double
}

///|
/// internal_ring_geometry computes the standard internal-gear radii:
///
/// ```text
/// pitch radius = module * teeth / 2
/// base radius  = pitch radius * cos(pressure angle)
/// tip radius   = pitch radius - addendum_factor * module
/// root radius  = pitch radius + dedendum_factor * module
/// ```
pub fn internal_ring_geometry(
  module_mm : Double,
  teeth : Int32,
  pressure_angle_deg : Double,
  addendum_factor~ : Double = 1.0,
  dedendum_factor~ : Double = 1.25,
) -> InternalRingGeometry {
  let pitch = module_mm * teeth.to_double() / 2.0
  let pa = pressure_angle_deg * @math.PI / 180.0
  {
    module_mm,
    teeth,
    pressure_angle_deg,
    pitch_radius_mm: pitch,
    base_radius_mm: pitch * @math.cos(pa),
    tip_radius_mm: pitch - addendum_factor * module_mm,
    root_radius_mm: pitch + dedendum_factor * module_mm,
    addendum_factor,
    dedendum_factor,
  }
}

///|
/// internal_involute_angle returns `inv(a_r) = tan(a_r) - a_r` at radius `r`.
fn internal_involute_angle(base_radius : Double, r : Double) -> Double {
  let t = involute_theta(base_radius, r)
  t - @math.atan(t)
}

///|
/// internal_ring_tooth_half_angle returns the half angular tooth thickness of
/// an internal gear at radius `r`:
///
/// `psi(r) = psi_p + inv(a_r) - inv(a_p)`
///
/// `psi_p = pi / (2 * teeth) - backlash / (2 * pitch_radius)` is the standard
/// reference tooth thickness `pi * m / 2` minus the declared backlash.
fn internal_ring_tooth_half_angle(
  base_radius : Double,
  inv_pitch_angle : Double,
  psi_p : Double,
  r : Double,
) -> Double {
  psi_p + internal_involute_angle(base_radius, r) - inv_pitch_angle
}

///|
/// internal_involute_ring_profile returns the exact internal involute bore
/// boundary of a ring gear in the XY plane, with tooth 0 centred on +X.
///
/// The returned loop is the *hole* boundary: the ring material lies outside it.
/// It is wound counter-clockwise; `ExtrudedProfile` normalises the hole winding
/// when it compiles the body.
///
/// Tooth thickness follows the standard internal involute relation, so a
/// standard external planet at the internal centre distance meshes with the
/// space. `backlash_mm` is a **per-gear** tooth-thickness reduction at the
/// pitch circle; it widens the ring space and thins the tooth. A mesh of a ring
/// and planet built with the same value therefore has `2 * backlash_mm` of
/// total circumferential clearance. Internal meshes of low-tooth-count
/// planets (for example z = 12 at 20 degrees) need a small declared backlash
/// (about `0.05 * module`) to clear the ring tooth tip through a full rotation
/// cycle; `internal_mesh_interference` and the tests check this.
///
/// The ring tip radius must be outside the base circle (`r_a > r_b`), which for
/// a standard 20 degree addendum requires roughly 34 or more ring teeth. A
/// smaller ring is rejected with a typed error instead of silently truncating
/// the involute at the base circle.
pub fn internal_involute_ring_profile(
  module_mm : Double,
  teeth : Int32,
  pressure_angle_deg : Double,
  backlash_mm~ : Double = 0.0,
  addendum_factor~ : Double = 1.0,
  dedendum_factor~ : Double = 1.25,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
) -> Result[Array[@cad.Vec2], @common.SpecError] {
  match @common.require_positive("ring module", module_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if teeth < 6 {
    return Err(@common.InvalidParameter("ring teeth must be >= 6"))
  }
  match
    @common.require_in_range("pressure angle", pressure_angle_deg, 10.0, 35.0) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("ring backlash", backlash_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("ring addendum factor", addendum_factor) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("ring dedendum factor", dedendum_factor) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let geom = internal_ring_geometry(
    module_mm,
    teeth,
    pressure_angle_deg,
    addendum_factor~,
    dedendum_factor~,
  )
  let rb = geom.base_radius_mm
  let rp = geom.pitch_radius_mm
  let ra = geom.tip_radius_mm
  let rf = geom.root_radius_mm
  if !(ra > rb + 1.0e-9) {
    return Err(
      @common.InvalidParameter(
        "ring tip radius r_p - addendum*m is at or below the base circle r_p*cos(pressure angle); reduce the addendum factor or increase the tooth count",
      ),
    )
  }
  let n = teeth.to_double()
  let pa = pressure_angle_deg * @math.PI / 180.0
  let inv_p = @math.tan(pa) - pa
  let psi_p = @math.PI / (2.0 * n) - backlash_mm / (2.0 * rp)
  if !(psi_p > 0.0) {
    return Err(
      @common.InvalidParameter(
        "ring backlash is too large: the tooth thickness at the pitch circle is not positive",
      ),
    )
  }
  let inv_points = if involute_points < 2 { 2 } else { involute_points }
  let arcs = if arc_points < 2 { 2 } else { arc_points }
  let pitch_angle = 2.0 * @math.PI / n
  let psi = fn(r : Double) -> Double {
    internal_ring_tooth_half_angle(rb, inv_p, psi_p, r)
  }
  let psi_tip = psi(ra)
  let psi_root = psi(rf)
  if !(psi_tip > 0.0) {
    return Err(
      @common.InvalidParameter(
        "ring tooth closes at the tip; reduce backlash or addendum",
      ),
    )
  }
  if 2.0 * psi_root >= pitch_angle {
    return Err(
      @common.InvalidParameter(
        "ring root space collapses; reduce backlash or dedendum",
      ),
    )
  }
  // One tooth sector of the bore boundary, tooth centred on +X.
  let sector : Array[@cad.Vec2] = []
  // Tip arc (the inward-most part of the boundary) from -psi_tip to +psi_tip.
  for k in 0..<=arcs {
    let a = -psi_tip + 2.0 * psi_tip * k.to_double() / arcs.to_double()
    sector.push((ra * @math.cos(a), ra * @math.sin(a)))
  }
  // +Y flank from the tip out to the root.
  for k in 1..<=inv_points {
    let r = ra + (rf - ra) * k.to_double() / inv_points.to_double()
    let a = psi(r)
    sector.push((r * @math.cos(a), r * @math.sin(a)))
  }
  // Root arc across the tooth gap to the next tooth.
  let root_span = pitch_angle - 2.0 * psi_root
  for k in 1..<arcs {
    let a = psi_root + root_span * k.to_double() / arcs.to_double()
    sector.push((rf * @math.cos(a), rf * @math.sin(a)))
  }
  // -Y flank of the next tooth, from the root back in to the tip.
  for k in 0..<=inv_points {
    let idx = inv_points - k
    let r = ra + (rf - ra) * idx.to_double() / inv_points.to_double()
    let a = pitch_angle - psi(r)
    sector.push((r * @math.cos(a), r * @math.sin(a)))
  }
  let outline : Array[@cad.Vec2] = []
  let sector_len = sector.length()
  for i in 0..<teeth {
    let theta = i.to_double() * pitch_angle
    for k in 0..<sector_len {
      outline.push(rotate_xy(sector[k], theta))
    }
  }
  let tol = 1.0e-12 * (1.0 + rf * rf)
  Ok(clean_polygon(outline, tol))
}

///|
/// internal_segments_cross reports a strict interior crossing of two segments.
/// Endpoint contact at the pitch point is not a crossing; a real flank overlap
/// produces one.
fn internal_segments_cross(
  a0 : @cad.Vec2,
  a1 : @cad.Vec2,
  b0 : @cad.Vec2,
  b1 : @cad.Vec2,
) -> Bool {
  let o1 = (a1.0 - a0.0) * (b0.1 - a0.1) - (a1.1 - a0.1) * (b0.0 - a0.0)
  let o2 = (a1.0 - a0.0) * (b1.1 - a0.1) - (a1.1 - a0.1) * (b1.0 - a0.0)
  let o3 = (b1.0 - b0.0) * (a0.1 - b0.1) - (b1.1 - b0.1) * (a0.0 - b0.0)
  let o4 = (b1.0 - b0.0) * (a1.1 - b0.1) - (b1.1 - b0.1) * (a1.0 - b0.0)
  let eps = 1.0e-12
  o1 * o2 < -eps && o3 * o4 < -eps
}

///|
/// internal_mesh_interference samples one complete internal-mesh rotation cycle
/// and returns the number of proper planet/ring tooth-outline crossings.
///
/// The planet is placed at the standard internal centre distance
/// `m (N - z_p) / 2` along +X with a tooth space facing the ring (the same phase
/// the planetary assembly uses). The planet advances by one angular pitch while
/// the ring turns in the same direction at `planet_teeth / ring_teeth` (the
/// internal rolling condition), sampled at `phases` poses. Zero crossings means
/// the two polygonal outlines interleave without interference through a cycle.
///
/// This is an outline (2D) check. It does not model helix, profile shift, load
/// deformation, or 3D contact.
pub fn internal_mesh_interference(
  module_mm : Double,
  ring_teeth : Int32,
  planet_teeth : Int32,
  pressure_angle_deg : Double,
  backlash_mm~ : Double = 0.0,
  addendum_factor~ : Double = 1.0,
  dedendum_factor~ : Double = 1.25,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
  phases~ : Int32 = 32,
) -> Result[Int32, @common.SpecError] {
  if planet_teeth < 6 {
    return Err(@common.InvalidParameter("planet teeth must be >= 6"))
  }
  if ring_teeth <= planet_teeth {
    return Err(
      @common.InvalidParameter(
        "internal mesh requires more ring teeth than planet teeth",
      ),
    )
  }
  let ring = match
    internal_involute_ring_profile(
      module_mm,
      ring_teeth,
      pressure_angle_deg,
      backlash_mm~,
      addendum_factor~,
      dedendum_factor~,
      involute_points~,
      arc_points~,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let planet = external_involute_outline(
    module_mm,
    planet_teeth,
    pressure_angle_deg,
    backlash_mm~,
    involute_points~,
    arc_points~,
  )
  let pitch_ring = module_mm * ring_teeth.to_double() / 2.0
  let center = module_mm * (ring_teeth - planet_teeth).to_double() / 2.0
  let phase_deg = 180.0 + 180.0 / planet_teeth.to_double()
  // For an odd planet tooth count the planet's sun-side and ring-side
  // orientations are half a planet pitch apart. The phase above is correct for
  // the sun mesh; the ring then needs a half ring-pitch offset. The planetary
  // assembly applies the same offset.
  let ring_phase_deg = if planet_teeth % 2 == 1 {
    180.0 / ring_teeth.to_double()
  } else {
    0.0
  }
  let steps = if phases < 1 { 1 } else { phases }
  let x_min = center - module_mm
  let x_max = pitch_ring + 4.0 * module_mm
  let y_max = pitch_ring
  let in_window = fn(p : @cad.Vec2) -> Bool {
    p.0 >= x_min && p.0 <= x_max && p.1.abs() <= y_max
  }
  let edges_in_window = fn(
    outline : Array[@cad.Vec2],
  ) -> Array[(@cad.Vec2, @cad.Vec2)] {
    let edges : Array[(@cad.Vec2, @cad.Vec2)] = []
    let len = outline.length()
    for i in 0..<len {
      let a = outline[i]
      let b = outline[(i + 1) % len]
      if in_window(a) || in_window(b) {
        edges.push((a, b))
      }
    }
    edges
  }
  let mut crossings = 0
  for step in 0..<steps {
    let planet_deg = 360.0 *
      step.to_double() /
      (planet_teeth.to_double() * steps.to_double())
    let ring_deg = planet_deg *
      planet_teeth.to_double() /
      ring_teeth.to_double()
    let planet_rad = (phase_deg + planet_deg) * @math.PI / 180.0
    let ring_rad = (ring_deg + ring_phase_deg) * @math.PI / 180.0
    let planet_world = planet.map(fn(p) {
      let q = rotate_xy(p, planet_rad)
      (q.0 + center, q.1)
    })
    let ring_world = ring.map(fn(p) { rotate_xy(p, ring_rad) })
    let ring_edges = edges_in_window(ring_world)
    let planet_edges = edges_in_window(planet_world)
    for (a0, a1) in ring_edges {
      for (b0, b1) in planet_edges {
        if internal_segments_cross(a0, a1, b0, b1) {
          crossings = crossings + 1
        }
      }
    }
  }
  Ok(crossings)
}

///|
/// internal_ring_gear_exact builds an exact internal involute ring gear body.
///
/// Axis +Z, base at z = 0. The outer boundary is circular; the bore is the exact
/// internal involute envelope from `internal_involute_ring_profile`. The
/// trapezoidal `internal_ring_gear` remains available as an explicit,
/// documented fallback for callers that need the old shape.
///
/// `outer_wall_mm` is the radial wall beyond the root circle. `backlash_mm`
/// widens the ring space; pass about `0.05 * module` when the ring must mesh
/// with a low-tooth-count planet over a full rotation cycle.
pub fn internal_ring_gear_exact(
  module_mm : Double,
  teeth : Int32,
  face_width_mm : Double,
  pressure_angle_deg~ : Double = 20.0,
  outer_wall_mm~ : Double = 5.0,
  backlash_mm~ : Double = 0.0,
  addendum_factor~ : Double = 1.0,
  dedendum_factor~ : Double = 1.25,
  involute_points~ : Int32 = 12,
  arc_points~ : Int32 = 8,
  detail~ : @common.DetailLevel = Detailed,
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("ring module", module_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("ring face width", face_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("ring outer wall", outer_wall_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let geom = internal_ring_geometry(
    module_mm,
    teeth,
    pressure_angle_deg,
    addendum_factor~,
    dedendum_factor~,
  )
  let bore = match
    internal_involute_ring_profile(
      module_mm,
      teeth,
      pressure_angle_deg,
      backlash_mm~,
      addendum_factor~,
      dedendum_factor~,
      involute_points~,
      arc_points~,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let outer_radius = geom.root_radius_mm + outer_wall_mm
  let arcs = if arc_points < 2 { 2 } else { arc_points }
  let policy = @common.DetailPolicy::for_level(detail)
  let segments = if policy.circle_segments < 48 {
    48
  } else {
    policy.circle_segments
  }
  let outer = @cad.Profile2D::circle(2.0 * outer_radius, segments~)
  let body = @cad.ExtrudedProfile::new(outer, face_width_mm, holes=[bore])
  let name = "ring-gear-m\{@cad.fmt_double(module_mm, None)}-z\{teeth}"
  Ok(
    with_gear_connectors(
      @common.Component::new(
        name~,
        metadata=@common.Metadata::new(
          designation="Internal ring gear m\{@cad.fmt_double(module_mm, None)} z\{teeth}",
          standard="ISO 53 basic rack internal involute form (zero profile shift)",
          family="internal ring gear",
          size="m\{@cad.fmt_double(module_mm, None)}-z\{teeth}",
          source="Exact internal involute envelope generated by this library from the standard basic rack; the flank is sampled as a polyline.",
        ),
        description="Circular ring with an exact internal involute toothed bore. Tooth thickness follows the standard internal relation psi(r) = psi_p + inv(a_r) - inv(a_p); tip/root arcs are sampled polylines.",
        features=@common.FeatureRecord::new(
          modeled=["body", "internal-involute-tooth-envelope"],
          approximated=[
            @common.Approximation::new(
              feature="internal-involute-flank",
              kind=@common.ApproximationKind::PolylineArc,
              deviation_mm=0.0,
              control="involute_points=\{involute_points}",
            ),
            @common.Approximation::new(
              feature="tip-and-root-arc",
              kind=@common.ApproximationKind::PolylineArc,
              deviation_mm=@common.chord_deviation(geom.tip_radius_mm, arcs),
              control="arc_points=\{arc_points}",
            ),
            @common.Approximation::new(
              feature="outer-boundary",
              kind=@common.ApproximationKind::PolylineArc,
              deviation_mm=@common.chord_deviation(outer_radius, segments),
              control="circle_segments=\{segments}",
            ),
          ],
          omitted=[
            @common.Omission::new(
              feature="root-fillet",
              reason="not modelled by this builder",
            ),
            @common.Omission::new(
              feature="tip-chamfer",
              reason="not modelled by this builder",
            ),
            @common.Omission::new(
              feature="profile-shift",
              reason="zero profile shift; a shifted ring needs a different basic-rack offset",
            ),
          ],
        ),
      ).add_layer(body, name="body", color=@cad.Rgb::purple()),
      0.0,
      2.0 * geom.pitch_radius_mm,
      2.0 * outer_radius,
      face_width_mm,
    ),
  )
}
