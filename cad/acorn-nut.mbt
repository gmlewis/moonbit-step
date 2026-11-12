///|
// DIN 1587 hexagon domed cap nut: the hexagon body of a conical-washer-face
// nut, a circular through bore, and a spherical dome. The dome is a spherical
// cap whose base circle is the cap diameter at the hexagon top; inside it a
// concentric spherical cavity leaves a uniform cap wall. All lateral surfaces
// are analytic (PLANE, CONICAL_SURFACE, CYLINDRICAL_SURFACE, SPHERICAL_SURFACE).

///|
priv struct AcornNutGeometry {
  rin : Double
  r_corner : Double
  hex_area : Double
  m : Double
  rb : Double
  tan_alpha : Double
  zc : Double
  z_b : Double
  z_t : Double
  rotation_deg : Double
  h : Double
  rd : Double
  rs : Double
  z_c : Double
  wall : Double
  ri : Double
  rc_base : Double
}

///|
fn acorn_nut_geometry(n : AcornNut) -> AcornNutGeometry? {
  let s = n.across_flats_mm
  let m = n.body_height_mm
  let rb = n.bore_diameter_mm / 2.0
  let h = n.total_height_mm
  let rd = n.dome_diameter_mm / 2.0
  let wall = n.wall_mm
  let alpha = n.face_angle_deg * @math.PI / 180.0
  let tan_alpha = @math.tan(alpha)
  if s <= 0.0 ||
    m <= 0.0 ||
    rb <= 0.0 ||
    h <= m ||
    rd <= 0.0 ||
    wall <= 0.0 ||
    tan_alpha <= 0.0 {
    return None
  }
  let rin = s / 2.0
  let r_corner = s / Double::sqrt(3.0)
  if rd >= rin - CAD_LENGTH_EPS {
    return None
  }
  let cap_height = h - m
  let rs = (rd * rd + cap_height * cap_height) / (2.0 * cap_height)
  if rs <= wall + CAD_LENGTH_EPS {
    return None
  }
  let z_c = m + cap_height - rs
  let ri = rs - wall
  let dz = z_c - m
  let base_sq = ri * ri - dz * dz
  if base_sq <= CAD_DEGENERATE_EPS {
    return None
  }
  let rc_base = Double::sqrt(base_sq)
  if rc_base <= rb + CAD_LENGTH_EPS || rc_base >= rd - CAD_LENGTH_EPS {
    return None
  }
  let zc = (r_corner - rin) / tan_alpha
  if 2.0 * zc >= m - CAD_LENGTH_EPS {
    return None
  }
  Some({
    rin,
    r_corner,
    hex_area: Double::sqrt(3.0) / 2.0 * s * s,
    m,
    rb,
    tan_alpha,
    zc,
    z_b: -rin / tan_alpha,
    z_t: m + rin / tan_alpha,
    rotation_deg: n.rotation_deg,
    h,
    rd,
    rs,
    z_c,
    wall,
    ri,
    rc_base,
  })
}

///|
/// acorn_nut_bounding_box returns the true axis-aligned extent.
pub fn acorn_nut_bounding_box(
  n : AcornNut,
) -> (Double, Double, Double, Double, Double, Double) {
  match acorn_nut_geometry(n) {
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
      (x0, x1, y0, y1, 0.0, g.h)
    }
  }
}

///|
/// acorn_nut_cone_radius returns the outer (cone) radius at `z` on the body.
fn acorn_nut_cone_radius(g : AcornNutGeometry, z : Double) -> Double {
  if z < g.zc {
    (z - g.z_b) * g.tan_alpha
  } else if z > g.m - g.zc {
    (g.z_t - z) * g.tan_alpha
  } else {
    g.r_corner
  }
}

///|
fn acorn_nut_hexdisk(
  r : Double,
  rin : Double,
  r_corner : Double,
  hex_area : Double,
) -> Double {
  if r <= rin {
    @math.PI * r * r
  } else if r >= r_corner {
    hex_area
  } else {
    @math.PI * r * r - 6.0 * conut_circular_segment(r, rin, r_corner)
  }
}

///|
/// acorn_nut_area_at returns the exact material cross-section area at `z`.
fn acorn_nut_area_at(g : AcornNutGeometry, z : Double) -> Double {
  if z < g.m {
    let outer = acorn_nut_hexdisk(
      acorn_nut_cone_radius(g, z),
      g.rin,
      g.r_corner,
      g.hex_area,
    )
    let area = outer - @math.PI * g.rb * g.rb
    if area < 0.0 {
      0.0
    } else {
      area
    }
  } else {
    let dz = z - g.z_c
    let ro_sq = g.rs * g.rs - dz * dz
    let ro = if ro_sq > 0.0 { Double::sqrt(ro_sq) } else { 0.0 }
    let ri_sq = g.ri * g.ri - dz * dz
    let ri = if ri_sq > 0.0 { Double::sqrt(ri_sq) } else { 0.0 }
    let area = @math.PI * (ro * ro - ri * ri)
    if area < 0.0 {
      0.0
    } else {
      area
    }
  }
}

///|
/// acorn_nut_volume_centroid integrates the exact solid volume by Simpson.
fn acorn_nut_volume_centroid(g : AcornNutGeometry) -> (Double, Double) {
  let zs : Array[Double] = [0.0, g.zc, g.m - g.zc, g.m, g.h - g.wall, g.h]
  let sorted = an_sort_unique(zs, 1.0e-9)
  let mut volume = 0.0
  let mut moment = 0.0
  let samples = 64
  for i in 0..<(sorted.length() - 1) {
    let z0 = sorted[i]
    let z1 = sorted[i + 1]
    let step = (z1 - z0) / Double::from_int(samples)
    if step <= CAD_DEGENERATE_EPS {
      continue
    }
    let mut span = 0.0
    let mut span_m = 0.0
    for j in 0..<=samples {
      let z = z0 + step * Double::from_int(j)
      let a = acorn_nut_area_at(g, z)
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
    volume = volume + span * step / 3.0
    moment = moment + span_m * step / 3.0
  }
  if volume <= CAD_DEGENERATE_EPS {
    (0.0, 0.0)
  } else {
    (volume, moment / volume)
  }
}

///|
/// AcornNut::volume returns the exact solid volume.
pub fn AcornNut::volume(self : AcornNut) -> Double {
  match acorn_nut_geometry(self) {
    Some(g) => acorn_nut_volume_centroid(g).0
    None => 0.0
  }
}

///|
/// AcornNut::centroid returns the exact centroid.
pub fn AcornNut::centroid(self : AcornNut) -> Vec3 {
  match acorn_nut_geometry(self) {
    Some(g) => (0.0, 0.0, acorn_nut_volume_centroid(g).1)
    None => (0.0, 0.0, 0.0)
  }
}

///|
/// an_acorn_nut_inventory mirrors the compiler's face emission: six flats,
/// twelve washer-face cones, three planes, one bore cylinder and two spheres.
fn an_acorn_nut_inventory(t : AcornNut) -> SurfaceInventory {
  match acorn_nut_geometry(t) {
    Some(_) => an_inventory(9, 1, 12, 2, 0, 0, 0, 0)
    None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
}

///|
/// acorn_nut_perimeter returns the material perimeter at `z`.
fn acorn_nut_perimeter(g : AcornNutGeometry, z : Double) -> Double {
  if z >= g.m {
    let dz = z - g.z_c
    let ro_sq = g.rs * g.rs - dz * dz
    let ro = if ro_sq > 0.0 { Double::sqrt(ro_sq) } else { 0.0 }
    let ri_sq = g.ri * g.ri - dz * dz
    let ri = if ri_sq > 0.0 { Double::sqrt(ri_sq) } else { 0.0 }
    return 2.0 * @math.PI * (ro + ri)
  }
  let bore_per = 2.0 * @math.PI * g.rb
  let period = @math.PI / 3.0
  let base = g.rotation_deg * @math.PI / 180.0
  let cone_r = acorn_nut_cone_radius(g, z)
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
/// an_acorn_nut_section returns the exact section at local `z`.
fn an_acorn_nut_section(
  t : AcornNut,
  z : Double,
) -> Result[Section, AnalysisError] {
  let g = match acorn_nut_geometry(t) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > g.h + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let area = acorn_nut_area_at(g, z)
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  if z >= g.m {
    let dz = z - g.z_c
    let ro_sq = g.rs * g.rs - dz * dz
    let ro = if ro_sq > 0.0 { Double::sqrt(ro_sq) } else { 0.0 }
    let ri_sq = g.ri * g.ri - dz * dz
    let ri = if ri_sq > 0.0 { Double::sqrt(ri_sq) } else { 0.0 }
    Ok({
      z_mm: z,
      area_mm2: area,
      perimeter_mm: acorn_nut_perimeter(g, z),
      outer_radius_mm: ro,
      inner_radius_mm: ri,
      rings: [{ inner_radius_mm: ri, outer_radius_mm: ro, }],
    })
  } else {
    let outer = acorn_nut_cone_radius(g, z)
    Ok({
      z_mm: z,
      area_mm2: area,
      perimeter_mm: acorn_nut_perimeter(g, z),
      outer_radius_mm: outer,
      inner_radius_mm: g.rb,
      rings: [{ inner_radius_mm: g.rb, outer_radius_mm: outer, }],
    })
  }
}

///|
/// acorn_hyperbola_samples samples the flat/cone intersection for one half of
/// a flat.
fn acorn_hyperbola_samples(
  g : AcornNutGeometry,
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
  pts
}

///|
/// acorn_bspline_curve builds a degree-1 B-spline 3D curve through `pts`.
fn acorn_bspline_curve(ctx : StepContext, pts : Array[Vec3]) -> @step.Ref {
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
/// compile_acorn_nut emits the cap nut as one closed STEP shell.
pub fn compile_acorn_nut(
  ctx : StepContext,
  node : SceneNode,
  n : AcornNut,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match acorn_nut_geometry(n) {
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
  let shoulder_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, g.m)), up, right)
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

  // Hyperbola edges (flat/cone), sampled B-splines with pcurves.
  let hb_left : Array[@step.Ref] = []
  let hb_right : Array[@step.Ref] = []
  let ht_left : Array[@step.Ref] = []
  let ht_right : Array[@step.Ref] = []
  for i in 0..<6 {
    let left_b = acorn_hyperbola_samples(g, xform, i, false, -1.0)
    let right_b = acorn_hyperbola_samples(g, xform, i, false, 1.0).rev()
    hb_left.push(
      hhp_surface_edge(
        ctx,
        acorn_bspline_curve(ctx, left_b),
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
        acorn_bspline_curve(ctx, right_b),
        right_b,
        flats[i],
        None,
        Some(bottom_cones[(i + 1) % 6]),
        context_2d,
        c_bot_vp[(i + 1) % 6],
        p_bot_vp[i],
      ),
    )
    let left_t = acorn_hyperbola_samples(g, xform, i, true, -1.0)
    let right_t = acorn_hyperbola_samples(g, xform, i, true, 1.0).rev()
    ht_left.push(
      hhp_surface_edge(
        ctx,
        acorn_bspline_curve(ctx, left_t),
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
        acorn_bspline_curve(ctx, right_t),
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

  // Circles shared by the annuli, bore, and spheres.
  let circles : Map[String, RevCircle] = Map([])
  let bore_bottom = rev_get_circle(ctx, xform, g.rb, 0.0, circles)
  let bore_top = rev_get_circle(ctx, xform, g.rb, g.m, circles)
  let dome_base = rev_get_circle(ctx, xform, g.rd, g.m, circles)
  let cavity_base = rev_get_circle(ctx, xform, g.rc_base, g.m, circles)

  // Bore seam (a straight generator at +X).
  let bore_seam_cp = hhwf_cp(ctx, xform.apply((g.rb, 0.0, 0.0)))
  let bore_seam = ctx.edge_curve(
    bore_bottom.vertex,
    bore_top.vertex,
    ctx.line(bore_seam_cp, ctx.vector(dir_up, 1.0)),
    true,
  )
  let cylinder = ctx.add(
    @repository.any_entity_cylindrical_surface(
      @geometry.CylindricalSurface::new(
        "",
        ctx.axis2_placement_3d(
          hhwf_cp(ctx, xform.apply((0.0, 0.0, 0.0))),
          dir_up,
          dir_right,
        ),
        @step.fmt_num(g.rb),
      ),
    ),
  )

  // Dome and cavity poles and seams.
  let pole = xform.apply((0.0, 0.0, g.h))
  let pole_cp = hhwf_cp(ctx, pole)
  let pole_vp = ctx.vertex_point(pole_cp)
  let cavity_pole = xform.apply((0.0, 0.0, g.h - g.wall))
  let cavity_pole_cp = hhwf_cp(ctx, cavity_pole)
  let cavity_pole_vp = ctx.vertex_point(cavity_pole_cp)
  let sphere_center = (0.0, g.z_c)
  let dome_seam = rev_seam_geometry(
    ctx,
    xform,
    (g.rd, g.m),
    (0.0, g.h),
    dome_base.vertex,
    pole_vp,
    Some(sphere_center),
  )
  let cavity_seam = rev_seam_geometry(
    ctx,
    xform,
    (g.rc_base, g.m),
    (0.0, g.h - g.wall),
    cavity_base.vertex,
    cavity_pole_vp,
    Some(sphere_center),
  )
  let sphere_at = fn(radius : Double) -> @step.Ref {
    ctx.add(
      @repository.any_entity_spherical_surface(
        @geometry.SphericalSurface::new(
          "",
          ctx.axis2_placement_3d(
            hhwf_cp(ctx, xform.apply((0.0, 0.0, g.z_c))),
            dir_up,
            dir_right,
          ),
          @step.fmt_num(radius),
        ),
      ),
    )
  }
  let dome_surface = sphere_at(g.rs)
  let cavity_surface = sphere_at(g.ri)

  // Bottom annulus: outer = the six bottom arcs, inner = the bore circle.
  let bottom_arcs_reversed : Array[@step.Ref] = []
  for k in 0..<6 {
    bottom_arcs_reversed.push(ctx.oriented_edge(arcs_bottom[5 - k], false))
  }
  let bottom_outer = ctx.edge_loop(bottom_arcs_reversed)
  let bottom_inner = ctx.edge_loop([ctx.oriented_edge(bore_bottom.edge, true)])
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
  // Top annulus: outer = the six top arcs, inner = the dome base circle.
  let top_forward : Array[@step.Ref] = []
  for k in 0..<6 {
    top_forward.push(ctx.oriented_edge(arcs_top[k], true))
  }
  let top_outer = ctx.edge_loop(top_forward)
  let top_inner = ctx.edge_loop([ctx.oriented_edge(dome_base.edge, false)])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(top_outer, true), ctx.face_bound(top_inner, true)],
      top_plane.surface,
      !reverse,
    ),
  )
  // Shoulder annulus: cavity base to the bore top circle.
  let shoulder_outer = ctx.edge_loop([ctx.oriented_edge(cavity_base.edge, true)])
  let shoulder_inner = ctx.edge_loop([ctx.oriented_edge(bore_top.edge, false)])
  faces.push(
    ctx.advanced_face(
      [
        ctx.face_outer_bound(shoulder_outer, true),
        ctx.face_bound(shoulder_inner, true),
      ],
      shoulder_plane.surface,
      !reverse,
    ),
  )
  // Bore: one full cylinder face with a seam.
  let bore_loop = ctx.edge_loop([
    ctx.oriented_edge(bore_seam, true),
    ctx.oriented_edge(bore_top.edge, true),
    ctx.oriented_edge(bore_seam, false),
    ctx.oriented_edge(bore_bottom.edge, false),
  ])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(bore_loop, true)],
      cylinder,
      reverse,
    ),
  )
  // Outer dome: a spherical cap with a seam to its pole.
  let dome_loop = ctx.edge_loop([
    ctx.oriented_edge(dome_seam, true),
    ctx.oriented_edge(dome_seam, false),
    ctx.oriented_edge(dome_base.edge, true),
  ])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(dome_loop, true)],
      dome_surface,
      !reverse,
    ),
  )
  // Inner cavity: a spherical cap, normal toward the cavity.
  let cavity_loop = ctx.edge_loop([
    ctx.oriented_edge(cavity_seam, true),
    ctx.oriented_edge(cavity_seam, false),
    ctx.oriented_edge(cavity_base.edge, false),
  ])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(cavity_loop, true)],
      cavity_surface,
      reverse,
    ),
  )
  faces
}

///|
/// acorn_nut_mesh builds a visualization mesh of the cap nut.
pub fn acorn_nut_mesh(
  n : AcornNut,
  angular_segments~ : Int32 = 96,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match acorn_nut_geometry(n) {
    Some(v) => v
    None => return ([], [])
  }
  let seg = if angular_segments < 24 { 24 } else { angular_segments }
  let period = @math.PI / 3.0
  let base = g.rotation_deg * @math.PI / 180.0
  let wall_at = fn(theta : Double) -> Double {
    let offset = theta - base - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    g.rin / @math.cos(delta)
  }
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let add_ring = fn(z : Double, radius : (Double) -> Double) -> Array[Int32] {
    let ring : Array[Int32] = []
    for j in 0..<seg {
      let theta = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(seg)
      let r = radius(theta)
      ring.push(verts.length())
      verts.push((r * @math.cos(theta), r * @math.sin(theta), z))
    }
    ring
  }
  let connect = fn(a : Array[Int32], b : Array[Int32]) -> Unit {
    for j in 0..<seg {
      let k = (j + 1) % seg
      faces.push([a[j], b[j], b[k], a[k]])
    }
  }
  // Hexagon body: outer washer-face/cone surface and the bore.
  let steps = 4
  let zs : Array[Double] = [0.0]
  for k in 1..<=steps {
    zs.push(g.zc * Double::from_int(k) / Double::from_int(steps))
  }
  zs.push(g.m - g.zc)
  for k in 1..<=steps {
    zs.push(g.m - g.zc + g.zc * Double::from_int(k) / Double::from_int(steps))
  }
  let outer_rings : Array[Array[Int32]] = []
  let inner_rings : Array[Array[Int32]] = []
  for z in zs {
    let cone = acorn_nut_cone_radius(g, z)
    outer_rings.push(
      add_ring(z, fn(theta) {
        let wall = wall_at(theta)
        if wall < cone {
          wall
        } else {
          cone
        }
      }),
    )
    inner_rings.push(add_ring(z, fn(_theta) { g.rb }))
  }
  let nz = zs.length()
  for li in 0..<(nz - 1) {
    connect(outer_rings[li], outer_rings[li + 1])
    for j in 0..<seg {
      let k = (j + 1) % seg
      faces.push([
        inner_rings[li][j],
        inner_rings[li][k],
        inner_rings[li + 1][k],
        inner_rings[li + 1][j],
      ])
    }
  }
  // Bottom annulus.
  let o0 = outer_rings[0]
  let i0 = inner_rings[0]
  for j in 0..<seg {
    let k = (j + 1) % seg
    faces.push([o0[j], i0[j], i0[k], o0[k]])
  }
  // Top annulus (hexagon rim to dome base) and shoulder (bore to cavity).
  // Build the dome and cavity base rings first so the annuli share them with
  // the spherical surfaces instead of duplicating the ring.
  let hex_ring = outer_rings[nz - 1]
  let bore_ring = inner_rings[nz - 1]
  let dome_steps = 12
  let cap_height = g.h - g.m
  let outer_r = fn(z : Double) -> Double {
    let dz = z - g.z_c
    let sq = g.rs * g.rs - dz * dz
    if sq > 0.0 {
      Double::sqrt(sq)
    } else {
      0.0
    }
  }
  let cavity_r = fn(z : Double) -> Double {
    let dz = z - g.z_c
    let sq = g.ri * g.ri - dz * dz
    if sq > 0.0 {
      Double::sqrt(sq)
    } else {
      0.0
    }
  }
  let dome_rings : Array[Array[Int32]] = []
  for k in 0..<dome_steps {
    let z = g.m +
      cap_height * Double::from_int(k) / Double::from_int(dome_steps)
    let r = outer_r(z)
    dome_rings.push(add_ring(z, fn(_theta) { r }))
  }
  let cavity_height = g.h - g.wall - g.m
  let cavity_rings : Array[Array[Int32]] = []
  for k in 0..<dome_steps {
    let z = g.m +
      cavity_height * Double::from_int(k) / Double::from_int(dome_steps)
    let r = cavity_r(z)
    cavity_rings.push(add_ring(z, fn(_theta) { r }))
  }
  connect(dome_rings[0], hex_ring)
  connect(cavity_rings[0], bore_ring)
  // Outer dome: rings from the base up to a pole fan.
  for k in 0..<(dome_rings.length() - 1) {
    connect(dome_rings[k], dome_rings[k + 1])
  }
  let dome_pole = verts.length()
  verts.push((0.0, 0.0, g.h))
  let top_ring = dome_rings[dome_rings.length() - 1]
  for j in 0..<seg {
    let k = (j + 1) % seg
    faces.push([top_ring[j], top_ring[k], dome_pole])
  }
  // Inner cavity: rings from the base up to its own pole.
  for k in 0..<(cavity_rings.length() - 1) {
    connect(cavity_rings[k], cavity_rings[k + 1])
  }
  let cavity_pole = verts.length()
  verts.push((0.0, 0.0, g.h - g.wall))
  let cavity_top = cavity_rings[cavity_rings.length() - 1]
  for j in 0..<seg {
    let k = (j + 1) % seg
    faces.push([cavity_top[k], cavity_top[j], cavity_pole])
  }
  (verts, faces)
}

///|
/// AcornNut::new builds a DIN 1587 cap nut.
pub fn AcornNut::new(
  across_flats_mm~ : Double,
  body_height_mm~ : Double,
  bore_diameter_mm~ : Double,
  total_height_mm~ : Double,
  dome_diameter_mm~ : Double,
  wall_mm~ : Double = 1.0,
  face_angle_deg~ : Double = 75.0,
  rotation_deg~ : Double = 0.0,
) -> AcornNut {
  {
    across_flats_mm,
    body_height_mm,
    bore_diameter_mm,
    total_height_mm,
    dome_diameter_mm,
    wall_mm,
    face_angle_deg,
    rotation_deg,
  }
}

///|
/// AcornNut::as_shape wraps the intent as a `Shape`.
pub fn AcornNut::as_shape(self : AcornNut) -> Shape {
  Shape::AcornNut(self)
}
