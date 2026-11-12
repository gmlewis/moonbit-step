///|
// Conical hexagon socket: a 45-degree countersink at the mouth and a 70-degree
// drill point at the floor, each trimmed by the six socket flats. The six rim
// patches and the drill patch reference one `CONICAL_SURFACE` each, so the
// analytic surface inventory is exactly the detailed ISO 4762 reference
// (plane 9, cone 5, cylinder 2) while every hex wall keeps its exact hyperbola
// boundary. Pcurves are attached on both adjacent faces (flat/cone or
// plane/cone) so importers never have to reconstruct a trimmed cone.

///|
priv struct ConicalSocketGeometry {
  top_z : Double
  top_radius : Double
  d : Double
  r_corner : Double
  hex_area : Double
  rim_apex : Double
  rim_tan : Double
  floor_apex : Double
  floor_tan : Double
  rotation_deg : Double
}

///|
fn conical_socket_geometry(s : SocketedSolid) -> ConicalSocketGeometry? {
  match s.body.validate() {
    Err(_) => return None
    Ok(_) => ()
  }
  let segs = s.body.segments
  let n = segs.length()
  if n < 2 {
    return None
  }
  let (top_radius, top_z) = match segs[n - 1] {
    RevLine(a, b) =>
      if b.0.abs() > CAD_LENGTH_EPS ||
        (a.1 - b.1).abs() > CAD_LENGTH_EPS ||
        a.0 <= 0.0 {
        return None
      } else {
        (a.0, b.1)
      }
    RevArc(_, _, _) => return None
  }
  let af = s.across_flats_mm
  let rim_tan = @math.tan(s.rim_angle_deg * @math.PI / 180.0)
  let floor_tan = @math.tan(s.floor_angle_deg * @math.PI / 180.0)
  if af <= 0.0 || rim_tan <= 0.0 || floor_tan <= 0.0 {
    return None
  }
  let d = af / 2.0
  let r_corner = af / Double::sqrt(3.0)
  let rim_apex = top_z - r_corner / rim_tan
  if s.socket_floor_z_mm >= rim_apex - CAD_LENGTH_EPS ||
    s.socket_floor_z_mm >= top_z - CAD_LENGTH_EPS {
    return None
  }
  if top_radius <= r_corner + CAD_LENGTH_EPS {
    return None
  }
  Some({
    top_z,
    top_radius,
    d,
    r_corner,
    hex_area: Double::sqrt(3.0) / 2.0 * af * af,
    rim_apex,
    rim_tan,
    floor_apex: s.socket_floor_z_mm,
    floor_tan,
    rotation_deg: s.rotation_deg,
  })
}

///|
/// conical_circular_segment returns the area of one circular segment cut off
/// by a hexagon flat at distance `d` from the axis, for `d <= r <= r_corner`.
fn conical_circular_segment(
  r : Double,
  d : Double,
  r_corner : Double,
) -> Double {
  if r <= d {
    return 0.0
  }
  let rc = if r > r_corner { r_corner } else { r }
  rc * rc * @math.acos(d / rc) - d * Double::sqrt(rc * rc - d * d)
}

///|
/// conical_socket_area_at returns the exact void cross-section area at `z`.
/// The void is the hexagon intersected with the drill cone, united with the
/// rim countersink disk.
fn conical_socket_area_at(g : ConicalSocketGeometry, z : Double) -> Double {
  if z < g.floor_apex - CAD_LENGTH_EPS || z > g.top_z + CAD_LENGTH_EPS {
    return 0.0
  }
  let rr = if z > g.rim_apex { (z - g.rim_apex) * g.rim_tan } else { 0.0 }
  let rf = if z > g.floor_apex { (z - g.floor_apex) * g.floor_tan } else { 0.0 }
  if rr >= rf && rr > 0.0 {
    return @math.PI * rr * rr
  }
  // area(hexagon intersect drill disk)
  let hex_part = if rf <= g.d {
    @math.PI * rf * rf
  } else if rf >= g.r_corner {
    g.hex_area
  } else {
    @math.PI * rf * rf - 6.0 * conical_circular_segment(rf, g.d, g.r_corner)
  }
  // area(rim disk outside the hexagon)
  let rim_part = if rr <= g.d {
    0.0
  } else if rr >= g.r_corner {
    @math.PI * rr * rr - g.hex_area
  } else {
    6.0 * conical_circular_segment(rr, g.d, g.r_corner)
  }
  hex_part + rim_part
}

///|
/// conical_socket_breakpoints returns every axial kink of the area function so
/// Simpson's rule samples smooth spans only.
fn conical_socket_breakpoints(g : ConicalSocketGeometry) -> Array[Double] {
  let zs : Array[Double] = [g.floor_apex, g.top_z]
  zs.push(g.floor_apex + g.d / g.floor_tan)
  zs.push(g.floor_apex + g.r_corner / g.floor_tan)
  zs.push(g.rim_apex + g.d / g.rim_tan)
  zs.push(g.rim_apex + g.r_corner / g.rim_tan)
  let clipped : Array[Double] = []
  for z in zs {
    if z > g.floor_apex - CAD_LENGTH_EPS && z < g.top_z + CAD_LENGTH_EPS {
      clipped.push(z)
    }
  }
  let sorted = an_sort_unique(clipped, 1.0e-9)
  sorted
}

///|
/// conical_socket_volume_centroid integrates the void exactly by composite
/// Simpson over the kink-free spans.
fn conical_socket_volume_centroid(
  g : ConicalSocketGeometry,
) -> (Double, Double) {
  let zs = conical_socket_breakpoints(g)
  let mut volume = 0.0
  let mut moment = 0.0
  let samples = 64
  for i in 0..<(zs.length() - 1) {
    let z0 = zs[i]
    let z1 = zs[i + 1]
    let h = (z1 - z0) / Double::from_int(samples)
    if h <= CAD_DEGENERATE_EPS {
      continue
    }
    let mut span = 0.0
    let mut span_m = 0.0
    for j in 0..<=samples {
      let z = z0 + h * Double::from_int(j)
      let a = conical_socket_area_at(g, z)
      let w = if j == 0 || j == samples {
        1.0
      } else if j % 2 == 1 {
        4.0
      } else {
        2.0
      }
      span = span + w * a
      span_m = span_m + w * a * z
    }
    span = span * h / 3.0
    span_m = span_m * h / 3.0
    volume = volume + span
    moment = moment + span_m
  }
  if volume <= CAD_DEGENERATE_EPS {
    (0.0, 0.0)
  } else {
    (volume, moment / volume)
  }
}

///|
/// conical_socket_void_perimeter returns the void boundary length at `z` in
/// polar form: rho(theta) = max(min(flat_distance, drill_radius), rim_radius).
fn conical_socket_void_perimeter(
  g : ConicalSocketGeometry,
  z : Double,
) -> Double {
  if z < g.floor_apex - CAD_LENGTH_EPS || z > g.top_z + CAD_LENGTH_EPS {
    return 0.0
  }
  let rr = if z > g.rim_apex { (z - g.rim_apex) * g.rim_tan } else { 0.0 }
  let rf = if z > g.floor_apex { (z - g.floor_apex) * g.floor_tan } else { 0.0 }
  let base = g.rotation_deg * @math.PI / 180.0
  let period = @math.PI / 3.0
  let n = 1440
  let step = 2.0 * @math.PI / Double::from_int(n)
  let rho_at = fn(theta : Double) -> Double {
    let offset = theta - base - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    let wall = g.d / @math.cos(delta)
    let inner = if wall < rf { wall } else { rf }
    if inner > rr {
      inner
    } else {
      rr
    }
  }
  let mut length = 0.0
  let cos_step = @math.cos(step)
  for i in 0..<n {
    let t0 = Double::from_int(i) * step
    let r0 = rho_at(t0)
    let r1 = rho_at(t0 + step)
    // Exact chord length between the two polar points.
    let chord = Double::sqrt(r0 * r0 + r1 * r1 - 2.0 * r0 * r1 * cos_step)
    length = length + chord
  }
  length
}

///|
/// conical_socket_body_circle fetches the body's top-cap circle edge so the
/// annular top face reuses the body's own edge and vertex.
fn conical_socket_top_circle(
  ctx : StepContext,
  xform : Transform,
  g : ConicalSocketGeometry,
  circles : Map[String, RevCircle],
) -> RevCircle {
  rev_get_circle(ctx, xform, g.top_radius, g.top_z, circles)
}

///|
/// compile_conical_socketed_solid emits a revolved body whose flat top cap is
/// replaced by a conical countersink, six hyperbola-trimmed flats, and a
/// conical drill floor. Every shared edge carries a pcurve on both adjacent
/// surfaces.
pub fn compile_conical_socketed_solid(
  ctx : StepContext,
  node : SceneNode,
  s : SocketedSolid,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match conical_socket_geometry(s) {
    Some(v) => v
    None => return []
  }
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let context_2d = ctx.context_2d()
  let circles : Map[String, RevCircle] = Map([])
  let faces : Array[@step.Ref] = []

  // Every revolved band except the flat top cap.
  let segs = s.body.segments
  let n = segs.length()
  for i in 0..<(n - 1) {
    let band = socketed_band(segs[i])
    match rev_compile_band(ctx, xform, band, up, right, circles, reverse~) {
      Some(f) => faces.push(f)
      None => ()
    }
  }
  let top_circle = conical_socket_top_circle(ctx, xform, g, circles)

  // Surfaces. One conical entity per cone; every patch references it.
  let top_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, g.top_z)), up, right)
  let rim_cone = hhp_cone(
    ctx,
    xform.apply((0.0, 0.0, g.rim_apex)),
    up,
    right,
    0.0,
    s.rim_angle_deg,
  )
  let drill_cone = hhp_cone(
    ctx,
    xform.apply((0.0, 0.0, g.floor_apex)),
    up,
    right,
    0.0,
    s.floor_angle_deg,
  )
  let flats : Array[HHPlaneRef] = []
  for i in 0..<6 {
    let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
      @math.PI /
      180.0
    // The plane axis points into the pocket (the face's outward normal): the
    // material is outside the hexagon, so the pocket wall faces the void.
    let normal = v_norm(
      xform.apply_dir((-@math.cos(psi), -@math.sin(psi), 0.0)),
    )
    let origin = xform.apply((g.d * @math.cos(psi), g.d * @math.sin(psi), 0.0))
    let tangent = v_norm(
      xform.apply_dir((-@math.sin(psi), @math.cos(psi), 0.0)),
    )
    flats.push(hhp_plane(ctx, origin, normal, tangent))
  }

  // Vertices.
  let corner_angle = fn(i : Int32) -> Double {
    (g.rotation_deg + 60.0 * Double::from_int(i)) * @math.PI / 180.0
  }
  let z_b = g.floor_apex + g.r_corner / g.floor_tan
  let top_pts : Array[Vec3] = []
  let bot_pts : Array[Vec3] = []
  for i in 0..<6 {
    let a = corner_angle(i)
    top_pts.push(
      xform.apply(
        (g.r_corner * @math.cos(a), g.r_corner * @math.sin(a), g.top_z),
      ),
    )
    bot_pts.push(
      xform.apply((g.r_corner * @math.cos(a), g.r_corner * @math.sin(a), z_b)),
    )
  }
  let top_cp = top_pts.map(fn(p) { hhwf_cp(ctx, p) })
  let bot_cp = bot_pts.map(fn(p) { hhwf_cp(ctx, p) })
  let top_vp = top_cp.map(fn(c) { ctx.vertex_point(c) })
  let bot_vp = bot_cp.map(fn(c) { ctx.vertex_point(c) })

  // Opening-circle arcs, shared by the annulus and the rim patches.
  let arcs : Array[@step.Ref] = []
  for i in 0..<6 {
    let a0 = corner_angle(i)
    let a1 = a0 + @math.PI / 3.0
    let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, g.top_z)))
    let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(g.r_corner)),
      ),
    )
    let samples : Array[Vec3] = []
    for k in 0..<=12 {
      let t = Double::from_int(k) / 12.0
      let a = a0 + (a1 - a0) * t
      samples.push(
        xform.apply(
          (g.r_corner * @math.cos(a), g.r_corner * @math.sin(a), g.top_z),
        ),
      )
    }
    arcs.push(
      hhp_surface_edge(
        ctx,
        circle,
        samples,
        top_plane,
        None,
        Some(rim_cone),
        context_2d,
        top_vp[i],
        top_vp[(i + 1) % 6],
      ),
    )
  }

  // Top hyperbolas (rim cone trimmed by each flat).
  let hyper_top : Array[@step.Ref] = []
  for i in 0..<6 {
    let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
      @math.PI /
      180.0
    let center = xform.apply(
      (g.d * @math.cos(psi), g.d * @math.sin(psi), g.rim_apex),
    )
    let axis = v_norm(xform.apply_dir((@math.cos(psi), @math.sin(psi), 0.0)))
    let a2p = ctx.axis2_placement_3d(
      hhwf_cp(ctx, center),
      ctx.direction(axis.0, axis.1, axis.2),
      ctx.direction(up.0, up.1, up.2),
    )
    let a = g.d / g.rim_tan
    let hyperbola = ctx.add(
      @repository.any_entity_hyperbola(
        @geometry.Hyperbola::new("", a2p, a, g.d),
      ),
    )
    let samples : Array[Vec3] = []
    let a0 = corner_angle(i)
    for k in 0..<=48 {
      let t = Double::from_int(k) / 48.0
      let theta = a0 + @math.PI / 3.0 * t
      let r = g.d / @math.cos(theta - psi)
      let z = g.rim_apex + r / g.rim_tan
      samples.push(xform.apply((r * @math.cos(theta), r * @math.sin(theta), z)))
    }
    hyper_top.push(
      hhp_surface_edge(
        ctx,
        hyperbola,
        samples,
        flats[i],
        None,
        Some(rim_cone),
        context_2d,
        top_vp[i],
        top_vp[(i + 1) % 6],
        edge_forward=false,
      ),
    )
  }

  // Bottom hyperbolas (drill cone trimmed by each flat).
  let hyper_bot : Array[@step.Ref] = []
  for i in 0..<6 {
    let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
      @math.PI /
      180.0
    let center = xform.apply(
      (g.d * @math.cos(psi), g.d * @math.sin(psi), g.floor_apex),
    )
    let axis = v_norm(xform.apply_dir((@math.cos(psi), @math.sin(psi), 0.0)))
    let a2p = ctx.axis2_placement_3d(
      hhwf_cp(ctx, center),
      ctx.direction(axis.0, axis.1, axis.2),
      ctx.direction(up.0, up.1, up.2),
    )
    let a = g.d / g.floor_tan
    let hyperbola = ctx.add(
      @repository.any_entity_hyperbola(
        @geometry.Hyperbola::new("", a2p, a, g.d),
      ),
    )
    let samples : Array[Vec3] = []
    let a0 = corner_angle(i)
    for k in 0..<=48 {
      let t = Double::from_int(k) / 48.0
      let theta = a0 + @math.PI / 3.0 * t
      let r = g.d / @math.cos(theta - psi)
      let z = g.floor_apex + r / g.floor_tan
      samples.push(xform.apply((r * @math.cos(theta), r * @math.sin(theta), z)))
    }
    hyper_bot.push(
      hhp_surface_edge(
        ctx,
        hyperbola,
        samples,
        flats[i],
        None,
        Some(drill_cone),
        context_2d,
        bot_vp[i],
        bot_vp[(i + 1) % 6],
        edge_forward=false,
      ),
    )
  }

  // Vertical corner edges (shared by the two adjacent flats).
  let verticals : Array[@step.Ref] = []
  for i in 0..<6 {
    let dir = v_norm(v_sub(bot_pts[i], top_pts[i]))
    let curve = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          top_cp[i],
          ctx.direction(dir.0, dir.1, dir.2) |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    verticals.push(
      hhp_surface_edge(
        ctx,
        curve,
        [top_pts[i], bot_pts[i]],
        flats[(i + 5) % 6],
        Some(flats[i]),
        None,
        context_2d,
        top_vp[i],
        bot_vp[i],
      ),
    )
  }

  // Drill seam: apex to the first bottom corner, on the drill cone only.
  let apex_pt = xform.apply((0.0, 0.0, g.floor_apex))
  let apex_cp = hhwf_cp(ctx, apex_pt)
  let apex_vp = ctx.vertex_point(apex_cp)
  let seam_dir = v_norm(v_sub(bot_pts[0], apex_pt))
  let seam_curve = ctx.add(
    @repository.any_entity_line(
      @geometry.Line::new(
        "",
        apex_cp,
        ctx.direction(seam_dir.0, seam_dir.1, seam_dir.2)
        |> d => { ctx.vector(d, 1.0) },
      ),
    ),
  )
  let seam_pc = hhp_pcurve_polyline(
    ctx,
    drill_cone.surface,
    [hhp_cone_uv(apex_pt, drill_cone), hhp_cone_uv(bot_pts[0], drill_cone)],
    context_2d,
    None,
  )
  let seam_edge = ctx.edge_curve(
    apex_vp,
    bot_vp[0],
    ctx.surface_curve(seam_curve, [seam_pc]),
    true,
  )

  // Flat faces.
  for i in 0..<6 {
    let face_loop = ctx.edge_loop([
      ctx.oriented_edge(hyper_top[i], true),
      ctx.oriented_edge(verticals[(i + 1) % 6], true),
      ctx.oriented_edge(hyper_bot[i], false),
      ctx.oriented_edge(verticals[i], false),
    ])
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(face_loop, true)],
        flats[i].surface,
        !reverse,
      ),
    )
  }
  // Rim cone patches (one per flat), all sharing the rim cone surface.
  for i in 0..<6 {
    let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
      @math.PI /
      180.0
    let natural = v_norm(
      xform.apply_dir(
        (-@math.cos(psi) / g.rim_tan, -@math.sin(psi) / g.rim_tan, 1.0),
      ),
    )
    let a0 = corner_angle(i)
    let mid_theta = a0 + @math.PI / 6.0
    let mid_r = g.d / @math.cos(mid_theta - psi)
    let mid = xform.apply(
      (
        mid_r * @math.cos(mid_theta),
        mid_r * @math.sin(mid_theta),
        g.rim_apex + mid_r / g.rim_tan,
      ),
    )
    let face_loop = ctx.edge_loop([
      ctx.oriented_edge(arcs[i], true),
      ctx.oriented_edge(hyper_top[i], false),
    ])
    let _ = mid
    let _ = natural
    let _ = top_pts
    // Pocket cone faces are the mirror sense of the exterior hex-head chamfer:
    // the detailed references write them `.F.`.
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(face_loop, true)],
        rim_cone.surface,
        reverse,
      ),
    )
  }
  // Drill cone face: seam out, six hyperbolas, seam back.
  let drill_loop_edges : Array[@step.Ref] = [ctx.oriented_edge(seam_edge, true)]
  for i in 0..<6 {
    drill_loop_edges.push(ctx.oriented_edge(hyper_bot[i], true))
  }
  drill_loop_edges.push(ctx.oriented_edge(seam_edge, false))
  let drill_loop = ctx.edge_loop(drill_loop_edges)
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(drill_loop, true)],
      drill_cone.surface,
      reverse,
    ),
  )
  // Annular top face: body top circle outside, opening arcs inside.
  let outer_loop = ctx.edge_loop([ctx.oriented_edge(top_circle.edge, true)])
  let inner_edges : Array[@step.Ref] = []
  for k in 0..<6 {
    inner_edges.push(ctx.oriented_edge(arcs[5 - k], false))
  }
  let inner_loop = ctx.edge_loop(inner_edges)
  // Reuse the top plane entity the arc pcurves reference, so every pcurve names
  // its own face's surface.
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(outer_loop, true), ctx.face_bound(inner_loop, true)],
      top_plane.surface,
      !reverse,
    ),
  )
  faces
}
