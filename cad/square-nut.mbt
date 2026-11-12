///|
// DIN 557 square nut: a square prism with a conical washer face on the top
// bearing face (one face only, per DIN 557) and a circular through bore. The
// chamfer is a true CONICAL_SURFACE trimmed by the four flats (hyperbola edges
// with pcurves), and the top face is the circle tangent to the four flats.

///|
priv struct SquareNutGeometry {
  rin : Double
  r_corner : Double
  area : Double
  m : Double
  rb : Double
  tan_alpha : Double
  zc : Double
  z_t : Double
  rotation_deg : Double
}

///|
fn square_nut_geometry(n : SquareNut) -> SquareNutGeometry? {
  let s = n.across_flats_mm
  let m = n.height_mm
  let rb = n.bore_diameter_mm / 2.0
  let alpha = n.face_angle_deg * @math.PI / 180.0
  let tan_alpha = @math.tan(alpha)
  if s <= 0.0 || m <= 0.0 || rb <= 0.0 || tan_alpha <= 0.0 {
    return None
  }
  let rin = s / 2.0
  let r_corner = rin * Double::sqrt(2.0)
  if rb >= rin - CAD_LENGTH_EPS {
    return None
  }
  let zc = (r_corner - rin) / tan_alpha
  if zc >= m - CAD_LENGTH_EPS {
    return None
  }
  Some({
    rin,
    r_corner,
    area: s * s,
    m,
    rb,
    tan_alpha,
    zc,
    z_t: m + rin / tan_alpha,
    rotation_deg: n.rotation_deg,
  })
}

///|
/// square_nut_bounding_box returns the true axis-aligned extent.
pub fn square_nut_bounding_box(
  n : SquareNut,
) -> (Double, Double, Double, Double, Double, Double) {
  match square_nut_geometry(n) {
    None => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    Some(g) => {
      let mut x0 = 0.0
      let mut x1 = 0.0
      let mut y0 = 0.0
      let mut y1 = 0.0
      for i in 0..<4 {
        let a = (g.rotation_deg + 90.0 * Double::from_int(i)) * @math.PI / 180.0
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
/// square_nut_cone_radius returns the top-chamfer cone radius at `z`; below
/// the chamfer it is the corner radius (the full square cross-section).
fn square_nut_cone_radius(g : SquareNutGeometry, z : Double) -> Double {
  let r = (g.z_t - z) * g.tan_alpha
  if r > g.r_corner {
    g.r_corner
  } else {
    r
  }
}

///|
fn square_nut_outer_area(g : SquareNutGeometry, r : Double) -> Double {
  if r <= g.rin {
    @math.PI * r * r
  } else if r >= g.r_corner {
    g.area
  } else {
    @math.PI * r * r - 4.0 * conut_circular_segment(r, g.rin, g.r_corner)
  }
}

///|
/// square_nut_area_at returns the exact material cross-section area at `z`.
fn square_nut_area_at(g : SquareNutGeometry, z : Double) -> Double {
  let outer = square_nut_outer_area(g, square_nut_cone_radius(g, z))
  let area = outer - @math.PI * g.rb * g.rb
  if area < 0.0 {
    0.0
  } else {
    area
  }
}

///|
/// square_nut_volume_centroid integrates the exact solid volume by Simpson.
fn square_nut_volume_centroid(g : SquareNutGeometry) -> (Double, Double) {
  let zs : Array[Double] = [0.0, g.m - g.zc, g.m]
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
      let a = square_nut_area_at(g, z)
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
/// SquareNut::volume returns the exact solid volume.
pub fn SquareNut::volume(self : SquareNut) -> Double {
  match square_nut_geometry(self) {
    Some(g) => square_nut_volume_centroid(g).0
    None => 0.0
  }
}

///|
/// SquareNut::centroid returns the exact centroid.
pub fn SquareNut::centroid(self : SquareNut) -> Vec3 {
  match square_nut_geometry(self) {
    Some(g) => (0.0, 0.0, square_nut_volume_centroid(g).1)
    None => (0.0, 0.0, 0.0)
  }
}

///|
/// an_square_nut_inventory mirrors the compiler's face emission: four flats,
/// two planes, four washer-face cones and one bore cylinder.
fn an_square_nut_inventory(t : SquareNut) -> SurfaceInventory {
  match square_nut_geometry(t) {
    Some(_) => an_inventory(6, 1, 4, 0, 0, 0, 0, 0)
    None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
}

///|
/// square_nut_perimeter returns the material perimeter at `z`.
fn square_nut_perimeter(g : SquareNutGeometry, z : Double) -> Double {
  let bore_per = 2.0 * @math.PI * g.rb
  let period = @math.PI / 2.0
  let base = g.rotation_deg * @math.PI / 180.0
  let cone_r = square_nut_cone_radius(g, z)
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
/// an_square_nut_section returns the exact section at local `z`.
fn an_square_nut_section(
  t : SquareNut,
  z : Double,
) -> Result[Section, AnalysisError] {
  let g = match square_nut_geometry(t) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > g.m + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let area = square_nut_area_at(g, z)
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  let outer = square_nut_cone_radius(g, z)
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: square_nut_perimeter(g, z),
    outer_radius_mm: outer,
    inner_radius_mm: g.rb,
    rings: [{ inner_radius_mm: g.rb, outer_radius_mm: outer, }],
  })
}

///|
/// square_nut_hyperbola_samples samples the flat/cone intersection for one
/// half of a flat.
fn square_nut_hyperbola_samples(
  g : SquareNutGeometry,
  xform : Transform,
  i : Int32,
  corner_side : Double,
) -> Array[Vec3] {
  let psi = (g.rotation_deg + 45.0 + 90.0 * Double::from_int(i)) *
    @math.PI /
    180.0
  let n = 48
  let pts : Array[Vec3] = []
  for k in 0..<=n {
    let t = Double::from_int(k) / Double::from_int(n)
    let theta = psi + corner_side * (45.0 * @math.PI / 180.0) * t
    let r = g.rin / @math.cos(theta - psi)
    let z = g.z_t - r / g.tan_alpha
    pts.push(xform.apply((r * @math.cos(theta), r * @math.sin(theta), z)))
  }
  pts
}

///|
/// square_nut_bspline_curve builds a degree-1 B-spline 3D curve through `pts`.
fn square_nut_bspline_curve(ctx : StepContext, pts : Array[Vec3]) -> @step.Ref {
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
/// compile_square_nut emits the square nut as one closed STEP shell.
pub fn compile_square_nut(
  ctx : StepContext,
  node : SceneNode,
  n : SquareNut,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match square_nut_geometry(n) {
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
  let flats : Array[HHPlaneRef] = []
  for i in 0..<4 {
    let psi = (g.rotation_deg + 45.0 + 90.0 * Double::from_int(i)) *
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
  let top_cones : Array[HHConeRef] = []
  for i in 0..<4 {
    let lead = (g.rotation_deg + 90.0 * Double::from_int(i)) * @math.PI / 180.0
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

  let corner_angle = fn(i : Int32) -> Double {
    (g.rotation_deg + 90.0 * Double::from_int(i)) * @math.PI / 180.0
  }
  let flat_angle = fn(i : Int32) -> Double {
    (g.rotation_deg + 45.0 + 90.0 * Double::from_int(i)) * @math.PI / 180.0
  }
  let p_top : Array[Vec3] = []
  let c_bot : Array[Vec3] = []
  let c_top : Array[Vec3] = []
  for i in 0..<4 {
    let fa = flat_angle(i)
    p_top.push(xform.apply((g.rin * @math.cos(fa), g.rin * @math.sin(fa), g.m)))
    let ca = corner_angle(i)
    c_bot.push(
      xform.apply((g.r_corner * @math.cos(ca), g.r_corner * @math.sin(ca), 0.0)),
    )
    c_top.push(
      xform.apply(
        (g.r_corner * @math.cos(ca), g.r_corner * @math.sin(ca), g.m - g.zc),
      ),
    )
  }
  let p_top_cp = p_top.map(fn(p) { hhwf_cp(ctx, p) })
  let c_bot_cp = c_bot.map(fn(p) { hhwf_cp(ctx, p) })
  let c_top_cp = c_top.map(fn(p) { hhwf_cp(ctx, p) })
  let p_top_vp = p_top_cp.map(fn(c) { ctx.vertex_point(c) })
  let c_bot_vp = c_bot_cp.map(fn(c) { ctx.vertex_point(c) })
  let c_top_vp = c_top_cp.map(fn(c) { ctx.vertex_point(c) })

  // Top face arcs at z = m (radius rin), one per flat gap.
  let arcs_top : Array[@step.Ref] = []
  for i in 0..<4 {
    let a0 = flat_angle(i)
    let a1 = a0 + @math.PI / 2.0
    let center_t = hhwf_cp(ctx, xform.apply((0.0, 0.0, g.m)))
    let a2p_t = ctx.axis2_placement_3d(center_t, dir_up, dir_right)
    let circle_t = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p_t, @step.fmt_num(g.rin)),
      ),
    )
    let st : Array[Vec3] = []
    for k in 0..<=12 {
      let t = Double::from_int(k) / 12.0
      let a = a0 + (a1 - a0) * t
      st.push(xform.apply((g.rin * @math.cos(a), g.rin * @math.sin(a), g.m)))
    }
    arcs_top.push(
      hhp_surface_edge(
        ctx,
        circle_t,
        st,
        top_plane,
        None,
        Some(top_cones[(i + 1) % 4]),
        context_2d,
        p_top_vp[i],
        p_top_vp[(i + 1) % 4],
      ),
    )
  }

  // Top hyperbola edges (flat/cone).
  let ht_left : Array[@step.Ref] = []
  let ht_right : Array[@step.Ref] = []
  for i in 0..<4 {
    let left = square_nut_hyperbola_samples(g, xform, i, -1.0)
    let right = square_nut_hyperbola_samples(g, xform, i, 1.0).rev()
    ht_left.push(
      hhp_surface_edge(
        ctx,
        square_nut_bspline_curve(ctx, left),
        left,
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
        square_nut_bspline_curve(ctx, right),
        right,
        flats[i],
        None,
        Some(top_cones[(i + 1) % 4]),
        context_2d,
        c_top_vp[(i + 1) % 4],
        p_top_vp[i],
      ),
    )
  }

  // Bottom edges (the square rim) and vertical corners.
  let bottom_edges : Array[@step.Ref] = []
  let verticals : Array[@step.Ref] = []
  for i in 0..<4 {
    let j = (i + 1) % 4
    let dir = v_norm(v_sub(c_bot[j], c_bot[i]))
    let line = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          c_bot_cp[i],
          ctx.direction(dir.0, dir.1, dir.2) |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    bottom_edges.push(
      hhp_surface_edge(
        ctx,
        line,
        [c_bot[i], c_bot[j]],
        bottom_plane,
        Some(flats[i]),
        None,
        context_2d,
        c_bot_vp[i],
        c_bot_vp[j],
      ),
    )
    let vdir = v_norm(v_sub(c_top[i], c_bot[i]))
    let vline = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          c_bot_cp[i],
          ctx.direction(vdir.0, vdir.1, vdir.2) |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    verticals.push(
      hhp_surface_edge(
        ctx,
        vline,
        [c_bot[i], c_top[i]],
        flats[(i + 3) % 4],
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
  for i in 0..<4 {
    let face_loop = ctx.edge_loop([
      ctx.oriented_edge(bottom_edges[i], true),
      ctx.oriented_edge(verticals[(i + 1) % 4], true),
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
  // Top washer-face cones (one patch per corner).
  for i in 0..<4 {
    let fa = corner_angle(i)
    let natural = v_norm(
      xform.apply_dir((@math.cos(fa), @math.sin(fa), g.tan_alpha)),
    )
    let top_loop = ctx.edge_loop([
      ctx.oriented_edge(arcs_top[(i + 3) % 4], false),
      ctx.oriented_edge(ht_right[(i + 3) % 4], false),
      ctx.oriented_edge(ht_left[i], false),
    ])
    let top_points = [p_top[i], p_top[(i + 3) % 4], c_top[i]]
    let same = v_dot(hhwf_newell(top_points), natural) >= 0.0
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(top_loop, true)],
        top_cones[i].surface,
        same,
      ),
    )
  }

  // Bore circles and the cylinder.
  let circles : Map[String, RevCircle] = Map([])
  let bore_bottom = rev_get_circle(ctx, xform, g.rb, 0.0, circles)
  let bore_top = rev_get_circle(ctx, xform, g.rb, g.m, circles)
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

  // Bottom face: square rim to the bore circle.
  let bottom_outer = ctx.edge_loop([
    ctx.oriented_edge(bottom_edges[3], false),
    ctx.oriented_edge(bottom_edges[2], false),
    ctx.oriented_edge(bottom_edges[1], false),
    ctx.oriented_edge(bottom_edges[0], false),
  ])
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
  // Top face: the four arcs to the bore circle.
  let top_outer = ctx.edge_loop([
    ctx.oriented_edge(arcs_top[0], true),
    ctx.oriented_edge(arcs_top[1], true),
    ctx.oriented_edge(arcs_top[2], true),
    ctx.oriented_edge(arcs_top[3], true),
  ])
  let top_inner = ctx.edge_loop([ctx.oriented_edge(bore_top.edge, false)])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(top_outer, true), ctx.face_bound(top_inner, true)],
      top_plane.surface,
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
  faces
}

///|
/// square_nut_mesh builds a visualization mesh of the square nut.
pub fn square_nut_mesh(
  n : SquareNut,
  angular_segments~ : Int32 = 96,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match square_nut_geometry(n) {
    Some(v) => v
    None => return ([], [])
  }
  let seg = if angular_segments < 24 { 24 } else { angular_segments }
  let period = @math.PI / 2.0
  let base = g.rotation_deg * @math.PI / 180.0
  let wall_at = fn(theta : Double) -> Double {
    let offset = theta - base - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    g.rin / @math.cos(delta)
  }
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let steps = 4
  let zs : Array[Double] = [0.0, g.m - g.zc]
  for k in 1..<=steps {
    zs.push(g.m - g.zc + g.zc * Double::from_int(k) / Double::from_int(steps))
  }
  let outer_rings : Array[Array[Int32]] = []
  let inner_rings : Array[Array[Int32]] = []
  for z in zs {
    let cone = square_nut_cone_radius(g, z)
    let outer : Array[Int32] = []
    let inner : Array[Int32] = []
    for j in 0..<seg {
      let theta = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(seg)
      let wall = wall_at(theta)
      let r = if wall < cone { wall } else { cone }
      outer.push(verts.length())
      verts.push((r * @math.cos(theta), r * @math.sin(theta), z))
      inner.push(verts.length())
      verts.push((g.rb * @math.cos(theta), g.rb * @math.sin(theta), z))
    }
    outer_rings.push(outer)
    inner_rings.push(inner)
  }
  let nz = zs.length()
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
/// SquareNut::new builds a DIN 557 square nut.
pub fn SquareNut::new(
  across_flats_mm~ : Double,
  height_mm~ : Double,
  bore_diameter_mm~ : Double,
  face_angle_deg~ : Double = 75.0,
  rotation_deg~ : Double = 45.0,
) -> SquareNut {
  {
    across_flats_mm,
    height_mm,
    bore_diameter_mm,
    face_angle_deg,
    rotation_deg,
  }
}

///|
/// SquareNut::as_shape wraps the intent as a `Shape`.
pub fn SquareNut::as_shape(self : SquareNut) -> Shape {
  Shape::SquareNut(self)
}
