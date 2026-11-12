///|
// Hexagon nut with a conical washer face on each bearing face and a through
// bore. The face chamfers are true cones trimmed by the six flats (hyperbola
// edges with pcurves), matching the detailed ISO 4032 / DIN 934 references.

///|
priv struct ConicalNutGeometry {
  rin : Double
  r_corner : Double
  hex_area : Double
  m : Double
  rb : Double
  lead : Double
  mouth : Double
  tan_alpha : Double
  zc : Double
  z_b : Double
  z_t : Double
  rotation_deg : Double
}

///|
fn conical_nut_geometry(n : ConicalNut) -> ConicalNutGeometry? {
  let s = n.across_flats_mm
  let m = n.height_mm
  let rb = n.bore_diameter_mm / 2.0
  let alpha = n.face_angle_deg * @math.PI / 180.0
  let tan_alpha = @math.tan(alpha)
  if s <= 0.0 || m <= 0.0 || rb <= 0.0 || tan_alpha <= 0.0 {
    return None
  }
  let rin = s / 2.0
  let r_corner = s / Double::sqrt(3.0)
  let lead = if n.lead_in_mm > 0.0 { n.lead_in_mm } else { 0.0 }
  let mouth = rb + lead
  if mouth >= rin - CAD_LENGTH_EPS {
    return None
  }
  let zc = (r_corner - rin) / tan_alpha
  if 2.0 * zc >= m - CAD_LENGTH_EPS || 2.0 * lead >= m - CAD_LENGTH_EPS {
    return None
  }
  Some({
    rin,
    r_corner,
    hex_area: Double::sqrt(3.0) / 2.0 * s * s,
    m,
    rb,
    lead,
    mouth,
    tan_alpha,
    zc,
    z_b: -rin / tan_alpha,
    z_t: m + rin / tan_alpha,
    rotation_deg: n.rotation_deg,
  })
}

///|
/// conical_nut_bounding_box returns the true (trimmed) axis-aligned extent.
pub fn conical_nut_bounding_box(
  n : ConicalNut,
) -> (Double, Double, Double, Double, Double, Double) {
  match conical_nut_geometry(n) {
    None => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    Some(g) => {
      let mut x0 = 0.0
      let mut x1 = 0.0
      let mut y0 = 0.0
      let mut y1 = 0.0
      for i in 0..<6 {
        let a = (g.rotation_deg + 60.0 * Double::from_int(i)) * @math.PI / 180.0
        let x = g.r_corner * @math.cos(a)
        let y = g.r_corner * @math.sin(a)
        if x < x0 {
          x0 = x
        }
        if x > x1 {
          x1 = x
        }
        if y < y0 {
          y0 = y
        }
        if y > y1 {
          y1 = y
        }
      }
      (x0, x1, y0, y1, 0.0, g.m)
    }
  }
}

///|
/// conut_bspline_curve builds a degree-1 B-spline 3D curve through `pts` in
/// order, so the edge direction is explicit.
fn conut_bspline_curve(ctx : StepContext, pts : Array[Vec3]) -> @step.Ref {
  let n = pts.length()
  let cps = pts.map(fn(p) { hhwf_cp(ctx, p) })
  let mults : Array[Int32] = [2]
  for _ in 1..<(n - 1) {
    mults.push(1)
  }
  mults.push(2)
  let knots : Array[String] = []
  for i in 0..<n {
    knots.push(@step.fmt_num(Double::from_int(i)))
  }
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", 1, cps, ".UNSPECIFIED.", false, false, mults, knots, ".UNSPECIFIED.",
  )
  ctx.add(@repository.any_entity_b_spline_curve_with_knots(curve))
}

///|
/// conut_hyperbola_samples samples the flat/cone intersection for one half of
/// a flat. `corner_side` is -1 for the flat's left corner and +1 for its right.
fn conut_hyperbola_samples(
  g : ConicalNutGeometry,
  xform : Transform,
  i : Int32,
  top : Bool,
  corner_side : Double,
) -> Array[Vec3] {
  let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
    @math.PI /
    180.0
  let n = 48
  let pts : Array[Vec3] = []
  for k in 0..<=n {
    let t = Double::from_int(k) / Double::from_int(n)
    let theta = psi + corner_side * (30.0 * @math.PI / 180.0) * t
    let r = g.rin / @math.cos(theta - psi)
    let z = if top { g.z_t - r / g.tan_alpha } else { g.z_b + r / g.tan_alpha }
    pts.push(xform.apply((r * @math.cos(theta), r * @math.sin(theta), z)))
  }
  // The left corner is at the start for a left half; the edge helpers need a
  // consistent start point, which callers pass explicitly below.
  if corner_side < 0.0 {
    pts
  } else {
    pts
  }
}

///|
/// compile_conical_nut emits the nut as one closed STEP shell.
pub fn compile_conical_nut(
  ctx : StepContext,
  node : SceneNode,
  n : ConicalNut,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match conical_nut_geometry(n) {
    Some(v) => v
    None => return []
  }
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let context_2d = ctx.context_2d()

  let bottom_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, 0.0)), down, right)
  let top_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, g.m)), up, right)
  // Surfaces.
  let flats : Array[HHPlaneRef] = []
  for i in 0..<6 {
    let psi = (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) *
      @math.PI /
      180.0
    let normal = v_norm(xform.apply_dir((@math.cos(psi), @math.sin(psi), 0.0)))
    let origin = xform.apply(
      (g.rin * @math.cos(psi), g.rin * @math.sin(psi), 0.0),
    )
    let tangent = v_norm(
      xform.apply_dir((-@math.sin(psi), @math.cos(psi), 0.0)),
    )
    flats.push(hhp_plane(ctx, origin, normal, tangent))
  }
  let bottom_cones : Array[HHConeRef] = []
  let top_cones : Array[HHConeRef] = []
  for i in 0..<6 {
    let lead = (g.rotation_deg + 60.0 * Double::from_int(i)) * @math.PI / 180.0
    bottom_cones.push(
      hhp_cone(
        ctx,
        xform.apply((0.0, 0.0, g.z_b)),
        up,
        v_norm(xform.apply_dir((@math.cos(lead), @math.sin(lead), 0.0))),
        0.0,
        n.face_angle_deg,
      ),
    )
    top_cones.push(
      hhp_cone(
        ctx,
        xform.apply((0.0, 0.0, g.z_t)),
        down,
        v_norm(xform.apply_dir((@math.cos(lead), @math.sin(lead), 0.0))),
        0.0,
        n.face_angle_deg,
      ),
    )
  }

  // Vertices.
  let corner_angle = fn(i : Int32) -> Double {
    (g.rotation_deg + 60.0 * Double::from_int(i)) * @math.PI / 180.0
  }
  let flat_angle = fn(i : Int32) -> Double {
    (g.rotation_deg + 30.0 + 60.0 * Double::from_int(i)) * @math.PI / 180.0
  }
  let p_bot : Array[Vec3] = []
  let p_top : Array[Vec3] = []
  let c_bot : Array[Vec3] = []
  let c_top : Array[Vec3] = []
  for i in 0..<6 {
    let fa = flat_angle(i)
    p_bot.push(xform.apply((g.rin * @math.cos(fa), g.rin * @math.sin(fa), 0.0)))
    p_top.push(xform.apply((g.rin * @math.cos(fa), g.rin * @math.sin(fa), g.m)))
    let ca = corner_angle(i)
    c_bot.push(
      xform.apply(
        (g.r_corner * @math.cos(ca), g.r_corner * @math.sin(ca), g.zc),
      ),
    )
    c_top.push(
      xform.apply(
        (g.r_corner * @math.cos(ca), g.r_corner * @math.sin(ca), g.m - g.zc),
      ),
    )
  }
  let p_bot_cp = p_bot.map(fn(p) { hhwf_cp(ctx, p) })
  let p_top_cp = p_top.map(fn(p) { hhwf_cp(ctx, p) })
  let c_bot_cp = c_bot.map(fn(p) { hhwf_cp(ctx, p) })
  let c_top_cp = c_top.map(fn(p) { hhwf_cp(ctx, p) })
  let p_bot_vp = p_bot_cp.map(fn(c) { ctx.vertex_point(c) })
  let p_top_vp = p_top_cp.map(fn(c) { ctx.vertex_point(c) })
  let c_bot_vp = c_bot_cp.map(fn(c) { ctx.vertex_point(c) })
  let c_top_vp = c_top_cp.map(fn(c) { ctx.vertex_point(c) })

  // Face arcs at z = 0 and z = m (radius rin), one per flat gap.
  let arcs_bottom : Array[@step.Ref] = []
  let arcs_top : Array[@step.Ref] = []
  for i in 0..<6 {
    let a0 = flat_angle(i)
    let a1 = a0 + @math.PI / 3.0
    let center_b = hhwf_cp(ctx, xform.apply((0.0, 0.0, 0.0)))
    let center_t = hhwf_cp(ctx, xform.apply((0.0, 0.0, g.m)))
    let a2p_b = ctx.axis2_placement_3d(center_b, dir_up, dir_right)
    let a2p_t = ctx.axis2_placement_3d(center_t, dir_up, dir_right)
    let circle_b = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p_b, @step.fmt_num(g.rin)),
      ),
    )
    let circle_t = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p_t, @step.fmt_num(g.rin)),
      ),
    )
    let sb : Array[Vec3] = []
    let st : Array[Vec3] = []
    for k in 0..<=12 {
      let t = Double::from_int(k) / 12.0
      let a = a0 + (a1 - a0) * t
      sb.push(xform.apply((g.rin * @math.cos(a), g.rin * @math.sin(a), 0.0)))
      st.push(xform.apply((g.rin * @math.cos(a), g.rin * @math.sin(a), g.m)))
    }
    arcs_bottom.push(
      hhp_surface_edge(
        ctx,
        circle_b,
        sb,
        bottom_plane,
        None,
        Some(bottom_cones[(i + 1) % 6]),
        context_2d,
        p_bot_vp[i],
        p_bot_vp[(i + 1) % 6],
      ),
    )
    arcs_top.push(
      hhp_surface_edge(
        ctx,
        circle_t,
        st,
        top_plane,
        None,
        Some(top_cones[(i + 1) % 6]),
        context_2d,
        p_top_vp[i],
        p_top_vp[(i + 1) % 6],
      ),
    )
  }

  // Hyperbola edges (flat/cone). Each is a sampled B-spline with pcurves on the
  // flat and on the cone.
  let hb_left : Array[@step.Ref] = []
  let hb_right : Array[@step.Ref] = []
  let ht_left : Array[@step.Ref] = []
  let ht_right : Array[@step.Ref] = []
  for i in 0..<6 {
    let left_b = conut_hyperbola_samples(g, xform, i, false, -1.0)
    // The right half is sampled P_i -> corner; the edge runs corner -> P_i.
    let right_b = conut_hyperbola_samples(g, xform, i, false, 1.0).rev()
    hb_left.push(
      hhp_surface_edge(
        ctx,
        conut_bspline_curve(ctx, left_b),
        left_b,
        flats[i],
        None,
        Some(bottom_cones[i]),
        context_2d,
        p_bot_vp[i],
        c_bot_vp[i],
      ),
    )
    hb_right.push(
      hhp_surface_edge(
        ctx,
        conut_bspline_curve(ctx, right_b),
        right_b,
        flats[i],
        None,
        Some(bottom_cones[(i + 1) % 6]),
        context_2d,
        c_bot_vp[(i + 1) % 6],
        p_bot_vp[i],
      ),
    )
    let left_t = conut_hyperbola_samples(g, xform, i, true, -1.0)
    let right_t = conut_hyperbola_samples(g, xform, i, true, 1.0).rev()
    ht_left.push(
      hhp_surface_edge(
        ctx,
        conut_bspline_curve(ctx, left_t),
        left_t,
        flats[i],
        None,
        Some(top_cones[i]),
        context_2d,
        p_top_vp[i],
        c_top_vp[i],
      ),
    )
    ht_right.push(
      hhp_surface_edge(
        ctx,
        conut_bspline_curve(ctx, right_t),
        right_t,
        flats[i],
        None,
        Some(top_cones[(i + 1) % 6]),
        context_2d,
        c_top_vp[(i + 1) % 6],
        p_top_vp[i],
      ),
    )
  }

  // Vertical corner edges.
  let verticals : Array[@step.Ref] = []
  for i in 0..<6 {
    let dir = v_norm(v_sub(c_top[i], c_bot[i]))
    let curve = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          c_bot_cp[i],
          ctx.direction(dir.0, dir.1, dir.2) |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    verticals.push(
      hhp_surface_edge(
        ctx,
        curve,
        [c_bot[i], c_top[i]],
        flats[(i + 5) % 6],
        Some(flats[i]),
        None,
        context_2d,
        c_bot_vp[i],
        c_top_vp[i],
      ),
    )
  }

  let faces : Array[@step.Ref] = []
  // Flats.
  for i in 0..<6 {
    let face_loop = ctx.edge_loop([
      ctx.oriented_edge(hb_left[i], false),
      ctx.oriented_edge(hb_right[i], false),
      ctx.oriented_edge(verticals[(i + 1) % 6], true),
      ctx.oriented_edge(ht_right[i], true),
      ctx.oriented_edge(ht_left[i], true),
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
  // Bottom and top washer cones (one patch per corner).
  for i in 0..<6 {
    let fa = corner_angle(i)
    let bot_natural = v_norm(
      xform.apply_dir((@math.cos(fa), @math.sin(fa), -g.tan_alpha)),
    )
    let bot_loop = ctx.edge_loop([
      ctx.oriented_edge(arcs_bottom[(i + 5) % 6], true),
      ctx.oriented_edge(hb_left[i], true),
      ctx.oriented_edge(hb_right[(i + 5) % 6], true),
    ])
    let bot_points = [p_bot[(i + 5) % 6], p_bot[i], c_bot[i]]
    let bot_same = v_dot(hhwf_newell(bot_points), bot_natural) >= 0.0
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(bot_loop, true)],
        bottom_cones[i].surface,
        bot_same,
      ),
    )
    let top_natural = v_norm(
      xform.apply_dir((@math.cos(fa), @math.sin(fa), g.tan_alpha)),
    )
    // The top cone patch is the reverse cycle of the flat's top edge, so the
    // shared top hyperbolas are traversed oppositely by the flat and the cone.
    let top_loop = ctx.edge_loop([
      ctx.oriented_edge(arcs_top[(i + 5) % 6], false),
      ctx.oriented_edge(ht_right[(i + 5) % 6], false),
      ctx.oriented_edge(ht_left[i], false),
    ])
    let top_points = [p_top[i], p_top[(i + 5) % 6], c_top[i]]
    let top_same = v_dot(hhwf_newell(top_points), top_natural) >= 0.0
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(top_loop, true)],
        top_cones[i].surface,
        top_same,
      ),
    )
  }

  // Bore: cylinder plus optional 45-degree lead-in cones, each a face with a
  // seam; the end circles are the inner boundaries of the face annuli.
  let bore_levels : Array[(Double, Double)] = []
  if g.lead > 0.0 {
    bore_levels.push((0.0, g.mouth))
    bore_levels.push((g.lead, g.rb))
    bore_levels.push((g.m - g.lead, g.rb))
    bore_levels.push((g.m, g.mouth))
  } else {
    bore_levels.push((0.0, g.rb))
    bore_levels.push((g.m, g.rb))
  }
  let nl = bore_levels.length()
  let bore_v0 : Array[@step.Ref] = []
  let bore_v1 : Array[@step.Ref] = []
  let bore_cp0 : Array[@step.Ref] = []
  let bore_cp1 : Array[@step.Ref] = []
  let bore_arc_a : Array[@step.Ref] = []
  let bore_arc_b : Array[@step.Ref] = []
  for li in 0..<nl {
    let (z, r) = bore_levels[li]
    let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, z)))
    let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(r)),
      ),
    )
    let cp0 = hhwf_cp(ctx, xform.apply((r, 0.0, z)))
    let cp1 = hhwf_cp(ctx, xform.apply((-r, 0.0, z)))
    let vp0 = ctx.vertex_point(cp0)
    let vp1 = ctx.vertex_point(cp1)
    bore_cp0.push(cp0)
    bore_cp1.push(cp1)
    bore_v0.push(vp0)
    bore_v1.push(vp1)
    // Half circles: +X -> -X (a) and -X -> +X (b).
    bore_arc_a.push(ctx.edge_curve(vp0, vp1, circle, true))
    bore_arc_b.push(ctx.edge_curve(vp1, vp0, circle, true))
  }
  for li in 0..<(nl - 1) {
    let (z0, r0) = bore_levels[li]
    let (z1, r1) = bore_levels[li + 1]
    let d0 = v_norm(
      v_sub(xform.apply((r1, 0.0, z1)), xform.apply((r0, 0.0, z0))),
    )
    let d1 = v_norm(
      v_sub(xform.apply((-r1, 0.0, z1)), xform.apply((-r0, 0.0, z0))),
    )
    let seam0 = ctx.edge_curve(
      bore_v0[li],
      bore_v0[li + 1],
      ctx.line(bore_cp0[li], ctx.vector(ctx.direction(d0.0, d0.1, d0.2), 1.0)),
      true,
    )
    let seam1 = ctx.edge_curve(
      bore_v1[li],
      bore_v1[li + 1],
      ctx.line(bore_cp1[li], ctx.vector(ctx.direction(d1.0, d1.1, d1.2), 1.0)),
      true,
    )
    let surface = if (r0 - r1).abs() < CAD_LENGTH_EPS {
      let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, z0)))
      let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
      ctx.add(
        @repository.any_entity_cylindrical_surface(
          @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(r0)),
        ),
      )
    } else if r1 < r0 {
      // Radius shrinks upward: apex above, opening downward.
      hhwf_cone(ctx, xform.apply((0.0, 0.0, z0 + r0)), down, right, 0.0, 45.0)
    } else {
      hhwf_cone(ctx, xform.apply((0.0, 0.0, z0 - r0)), up, right, 0.0, 45.0)
    }
    let loop_a = ctx.edge_loop([
      ctx.oriented_edge(seam0, true),
      ctx.oriented_edge(bore_arc_a[li + 1], true),
      ctx.oriented_edge(seam1, false),
      ctx.oriented_edge(bore_arc_a[li], false),
    ])
    let loop_b = ctx.edge_loop([
      ctx.oriented_edge(seam1, true),
      ctx.oriented_edge(bore_arc_b[li + 1], true),
      ctx.oriented_edge(seam0, false),
      ctx.oriented_edge(bore_arc_b[li], false),
    ])
    faces.push(
      ctx.advanced_face([ctx.face_outer_bound(loop_a, true)], surface, reverse),
    )
    faces.push(
      ctx.advanced_face([ctx.face_outer_bound(loop_b, true)], surface, reverse),
    )
  }
  // Face annuli: outer = the six arcs, inner = the bore mouth circle.
  // The annulus outer loop must traverse each arc opposite to its cone patch.
  let bottom_arcs_reversed : Array[@step.Ref] = []
  for k in 0..<6 {
    bottom_arcs_reversed.push(ctx.oriented_edge(arcs_bottom[5 - k], false))
  }
  let bottom_outer = ctx.edge_loop(bottom_arcs_reversed)
  let bottom_inner = ctx.edge_loop([
    ctx.oriented_edge(bore_arc_a[0], true),
    ctx.oriented_edge(bore_arc_b[0], true),
  ])
  faces.push(
    ctx.advanced_face(
      [
        ctx.face_outer_bound(bottom_outer, true),
        ctx.face_bound(bottom_inner, true),
      ],
      bottom_plane.surface,
      !reverse,
    ),
  )
  // The top cone patches use the arcs reversed; the top annulus uses them
  // forward, so each arc is shared in opposite directions.
  let top_forward : Array[@step.Ref] = []
  for k in 0..<6 {
    top_forward.push(ctx.oriented_edge(arcs_top[k], true))
  }
  let top_outer = ctx.edge_loop(top_forward)
  let top_inner = ctx.edge_loop([
    ctx.oriented_edge(bore_arc_b[nl - 1], false),
    ctx.oriented_edge(bore_arc_a[nl - 1], false),
  ])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(top_outer, true), ctx.face_bound(top_inner, true)],
      top_plane.surface,
      !reverse,
    ),
  )
  faces
}

///|
/// conut_circular_segment returns one circular-segment area outside a flat.
fn conut_circular_segment(r : Double, d : Double, r_corner : Double) -> Double {
  if r <= d {
    return 0.0
  }
  let rc = if r > r_corner { r_corner } else { r }
  rc * rc * @math.acos(d / rc) - d * Double::sqrt(rc * rc - d * d)
}

///|
/// conical_nut_bore_radius returns the bore radius at `z`.
fn conical_nut_bore_radius(g : ConicalNutGeometry, z : Double) -> Double {
  if g.lead <= 0.0 {
    return g.rb
  }
  if z < g.lead {
    g.mouth - z
  } else if z > g.m - g.lead {
    g.rb + (z - (g.m - g.lead))
  } else {
    g.rb
  }
}

///|
/// conical_nut_area_at returns the exact material cross-section area at `z`.
fn conical_nut_area_at(g : ConicalNutGeometry, z : Double) -> Double {
  let mut outer = if z < g.zc {
    let r = (z - g.z_b) * g.tan_alpha
    conut_hexdisk(r, g)
  } else if z > g.m - g.zc {
    let r = (g.z_t - z) * g.tan_alpha
    conut_hexdisk(r, g)
  } else {
    g.hex_area
  }
  let bore = conical_nut_bore_radius(g, z)
  outer = outer - @math.PI * bore * bore
  if outer < 0.0 {
    0.0
  } else {
    outer
  }
}

///|
fn conut_hexdisk(r : Double, g : ConicalNutGeometry) -> Double {
  if r <= g.rin {
    @math.PI * r * r
  } else if r >= g.r_corner {
    g.hex_area
  } else {
    @math.PI * r * r - 6.0 * conut_circular_segment(r, g.rin, g.r_corner)
  }
}

///|
/// conical_nut_volume_centroid integrates the exact solid volume by Simpson.
fn conical_nut_volume_centroid(g : ConicalNutGeometry) -> (Double, Double) {
  let zs : Array[Double] = [0.0, g.zc, g.m - g.zc, g.m]
  if g.lead > 0.0 {
    zs.push(g.lead)
    zs.push(g.m - g.lead)
  }
  let sorted = an_sort_unique(zs, 1.0e-9)
  let mut volume = 0.0
  let mut moment = 0.0
  let samples = 64
  for i in 0..<(sorted.length() - 1) {
    let z0 = sorted[i]
    let z1 = sorted[i + 1]
    let h = (z1 - z0) / Double::from_int(samples)
    if h <= CAD_DEGENERATE_EPS {
      continue
    }
    let mut span = 0.0
    let mut span_m = 0.0
    for j in 0..<=samples {
      let z = z0 + h * Double::from_int(j)
      let a = conical_nut_area_at(g, z)
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
    volume = volume + span * h / 3.0
    moment = moment + span_m * h / 3.0
  }
  if volume <= CAD_DEGENERATE_EPS {
    (0.0, 0.0)
  } else {
    (volume, moment / volume)
  }
}

///|
/// conical_nut_perimeter returns the material perimeter at `z`.
fn conical_nut_perimeter(g : ConicalNutGeometry, z : Double) -> Double {
  let bore = conical_nut_bore_radius(g, z)
  let bore_per = 2.0 * @math.PI * bore
  // Outer boundary in polar form: rho(theta) = min(flat distance, cone radius).
  let period = @math.PI / 3.0
  let base = g.rotation_deg * @math.PI / 180.0
  let cone_r = if z < g.zc {
    (z - g.z_b) * g.tan_alpha
  } else if z > g.m - g.zc {
    (g.z_t - z) * g.tan_alpha
  } else {
    g.r_corner
  }
  let n = 720
  let step = 2.0 * @math.PI / Double::from_int(n)
  let cos_step = @math.cos(step)
  let rho_at = fn(theta : Double) -> Double {
    let offset = theta - base - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    let wall = g.rin / @math.cos(delta)
    if wall < cone_r {
      wall
    } else {
      cone_r
    }
  }
  let mut length = 0.0
  for i in 0..<n {
    let r0 = rho_at(Double::from_int(i) * step)
    let r1 = rho_at(Double::from_int(i + 1) * step)
    length = length + Double::sqrt(r0 * r0 + r1 * r1 - 2.0 * r0 * r1 * cos_step)
  }
  length + bore_per
}

///|
/// conical_nut_cone_radius returns the outer (cone) radius at `z`.
fn conical_nut_cone_radius(g : ConicalNutGeometry, z : Double) -> Double {
  if z < g.zc {
    (z - g.z_b) * g.tan_alpha
  } else if z > g.m - g.zc {
    (g.z_t - z) * g.tan_alpha
  } else {
    g.r_corner
  }
}

///|
/// an_conical_nut_section returns the exact section at local `z`.
fn an_conical_nut_section(
  n : ConicalNut,
  z : Double,
) -> Result[Section, AnalysisError] {
  let g = match conical_nut_geometry(n) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > g.m + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let area = conical_nut_area_at(g, z)
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  let bore = conical_nut_bore_radius(g, z)
  let outer = conical_nut_cone_radius(g, z)
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: conical_nut_perimeter(g, z),
    outer_radius_mm: outer,
    inner_radius_mm: bore,
    rings: [{ inner_radius_mm: bore, outer_radius_mm: outer, }],
  })
}

///|
/// conical_nut_mesh builds a visualization mesh of the nut.
pub fn conical_nut_mesh(
  n : ConicalNut,
  angular_segments~ : Int32 = 96,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match conical_nut_geometry(n) {
    Some(v) => v
    None => return ([], [])
  }
  let seg = if angular_segments < 24 { 24 } else { angular_segments }
  let steps = 4
  let zs : Array[Double] = []
  zs.push(0.0)
  for k in 1..<=steps {
    zs.push(g.zc * Double::from_int(k) / Double::from_int(steps))
  }
  zs.push(g.m - g.zc)
  for k in 1..<=steps {
    zs.push(g.m - g.zc + g.zc * Double::from_int(k) / Double::from_int(steps))
  }
  let period = @math.PI / 3.0
  let base = g.rotation_deg * @math.PI / 180.0
  let wall_at = fn(theta : Double) -> Double {
    let offset = theta - base - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    g.rin / @math.cos(delta)
  }
  let verts : Array[Vec3] = []
  let outer_rings : Array[Array[Int32]] = []
  let inner_rings : Array[Array[Int32]] = []
  let nz = zs.length()
  for z in zs {
    let cone_r = conical_nut_cone_radius(g, z)
    let bore_r = conical_nut_bore_radius(g, z)
    let outer_idx : Array[Int32] = []
    let inner_idx : Array[Int32] = []
    for j in 0..<seg {
      let theta = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(seg)
      let wall = wall_at(theta)
      let r = if wall < cone_r { wall } else { cone_r }
      outer_idx.push(verts.length())
      verts.push((r * @math.cos(theta), r * @math.sin(theta), z))
      inner_idx.push(verts.length())
      verts.push((bore_r * @math.cos(theta), bore_r * @math.sin(theta), z))
    }
    outer_rings.push(outer_idx)
    inner_rings.push(inner_idx)
  }
  let faces : Array[Array[Int32]] = []
  for li in 0..<(nz - 1) {
    let oa = outer_rings[li]
    let ob = outer_rings[li + 1]
    let ia = inner_rings[li]
    let ib = inner_rings[li + 1]
    for j in 0..<seg {
      let k = (j + 1) % seg
      faces.push([oa[j], ob[j], ob[k], oa[k]])
      faces.push([ia[j], ia[k], ib[k], ib[j]])
    }
  }
  let o0 = outer_rings[0]
  let i0 = inner_rings[0]
  let o1 = outer_rings[nz - 1]
  let i1 = inner_rings[nz - 1]
  for j in 0..<seg {
    let k = (j + 1) % seg
    faces.push([o0[j], i0[j], i0[k], o0[k]])
    faces.push([o1[j], o1[k], i1[k], i1[j]])
  }
  (verts, faces)
}

///|
/// ConicalNut::new builds a hexagon nut with conical washer faces.
pub fn ConicalNut::new(
  across_flats_mm~ : Double,
  height_mm~ : Double,
  bore_diameter_mm~ : Double,
  face_angle_deg~ : Double,
  lead_in_mm~ : Double = 0.0,
  rotation_deg~ : Double = 0.0,
) -> ConicalNut {
  {
    across_flats_mm,
    height_mm,
    bore_diameter_mm,
    face_angle_deg,
    lead_in_mm,
    rotation_deg,
  }
}

///|
/// ConicalNut::as_shape wraps the intent as a `Shape`.
pub fn ConicalNut::as_shape(self : ConicalNut) -> Shape {
  Shape::ConicalNut(self)
}
