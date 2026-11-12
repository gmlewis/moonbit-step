///|
// Straight tube with a full-length parallel-sided slot (an ISO 8752 slotted
// spring pin). Outer and inner surfaces are analytic cylinders, the slot walls
// are planes (y = +/- slot_width/2), and the end faces are C-shaped planes.

///|
priv struct SlitTubeGeometry {
  ro : Double
  ri : Double
  len : Double
  half : Double
  delta_o : Double
  delta_i : Double
  slot_area : Double
}

///|
fn slit_tube_geometry(t : SlitTube) -> SlitTubeGeometry? {
  let ro = t.outer_diameter_mm / 2.0
  let ri = t.inner_diameter_mm / 2.0
  let len = t.length_mm
  let half = t.slot_width_mm / 2.0
  if ro <= 0.0 ||
    ri <= 0.0 ||
    ri >= ro ||
    len <= 0.0 ||
    half <= 0.0 ||
    half >= ri {
    return None
  }
  let delta_o = @math.asin(half / ro)
  let delta_i = @math.asin(half / ri)
  let f = fn(rad : Double) -> Double {
    0.5 *
    (
      half * Double::sqrt(rad * rad - half * half) +
      rad * rad * @math.asin(half / rad)
    )
  }
  Some({
    ro,
    ri,
    len,
    half,
    delta_o,
    delta_i,
    slot_area: 2.0 * (f(ro) - f(ri)),
  })
}

///|
/// slit_tube_material_area returns the C-section area at any interior `z`.
fn slit_tube_material_area(g : SlitTubeGeometry) -> Double {
  @math.PI * (g.ro * g.ro - g.ri * g.ri) - g.slot_area
}

///|
/// SlitTube::volume returns the exact solid volume.
pub fn SlitTube::volume(self : SlitTube) -> Double {
  match slit_tube_geometry(self) {
    Some(g) => slit_tube_material_area(g) * g.len
    None => 0.0
  }
}

///|
/// SlitTube::centroid returns the exact centroid.
pub fn SlitTube::centroid(self : SlitTube) -> Vec3 {
  match slit_tube_geometry(self) {
    Some(g) => {
      let area = slit_tube_material_area(g)
      if area <= CAD_DEGENERATE_EPS {
        (0.0, 0.0, 0.0)
      } else {
        (-g.half * (g.ro * g.ro - g.ri * g.ri) / area, 0.0, g.len / 2.0)
      }
    }
    None => (0.0, 0.0, 0.0)
  }
}

///|
/// an_slit_tube_inventory mirrors the compiler's face emission: two analytic
/// cylinders, two slot-wall planes and two C-shaped end planes.
fn an_slit_tube_inventory(t : SlitTube) -> SurfaceInventory {
  match slit_tube_geometry(t) {
    Some(_) => an_inventory(4, 2, 0, 0, 0, 0, 0, 0)
    None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
}

///|
/// an_slit_tube_section returns the C-section at local `z`.
fn an_slit_tube_section(
  t : SlitTube,
  z : Double,
) -> Result[Section, AnalysisError] {
  let g = match slit_tube_geometry(t) {
    Some(v) => v
    None => return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > g.len + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let area = slit_tube_material_area(g)
  if area <= CAD_AREA_EPS {
    return Err(EmptySection)
  }
  let outer_perimeter = (2.0 * @math.PI - 2.0 * g.delta_o) * g.ro
  let inner_perimeter = (2.0 * @math.PI - 2.0 * g.delta_i) * g.ri
  let wall = Double::sqrt(g.ro * g.ro - g.half * g.half) -
    Double::sqrt(g.ri * g.ri - g.half * g.half)
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: outer_perimeter + inner_perimeter + 2.0 * wall,
    outer_radius_mm: g.ro,
    inner_radius_mm: g.ri,
    rings: [{ inner_radius_mm: g.ri, outer_radius_mm: g.ro, }],
  })
}

///|
/// compile_slit_tube emits the slotted tube as one closed shell.
pub fn compile_slit_tube(
  ctx : StepContext,
  node : SceneNode,
  t : SlitTube,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match slit_tube_geometry(t) {
    Some(v) => v
    None => return []
  }
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let xo = Double::sqrt(g.ro * g.ro - g.half * g.half)
  let xi = Double::sqrt(g.ri * g.ri - g.half * g.half)
  let pts = {
    let obp = xform.apply((xo, g.half, 0.0))
    let obm = xform.apply((xo, -g.half, 0.0))
    let otp = xform.apply((xo, g.half, g.len))
    let otm = xform.apply((xo, -g.half, g.len))
    let ibp = xform.apply((xi, g.half, 0.0))
    let ibm = xform.apply((xi, -g.half, 0.0))
    let itp = xform.apply((xi, g.half, g.len))
    let itm = xform.apply((xi, -g.half, g.len))
    [obp, obm, otp, otm, ibp, ibm, itp, itm]
  }
  let cps = pts.map(fn(p) { hhwf_cp(ctx, p) })
  let vps = cps.map(fn(c) { ctx.vertex_point(c) })
  let line_edge = fn(a : Int32, b : Int32) -> @step.Ref {
    let dir = v_norm(v_sub(pts[b], pts[a]))
    let curve = ctx.line(
      cps[a],
      ctx.vector(ctx.direction(dir.0, dir.1, dir.2), 1.0),
    )
    ctx.edge_curve(vps[a], vps[b], curve, true)
  }
  let arc_edge = fn(
    z : Double,
    rad : Double,
    a : Int32,
    b : Int32,
  ) -> @step.Ref {
    let center = hhwf_cp(ctx, xform.apply((0.0, 0.0, z)))
    let a2p = ctx.axis2_placement_3d(center, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(rad)),
      ),
    )
    ctx.edge_curve(vps[a], vps[b], circle, true)
  }
  // Canonical edges.
  let eB = arc_edge(0.0, g.ro, 0, 1)
  let eT = arc_edge(g.len, g.ro, 2, 3)
  let iB = arc_edge(0.0, g.ri, 4, 5)
  let iT = arc_edge(g.len, g.ri, 6, 7)
  let vOP = line_edge(0, 2)
  let vOM = line_edge(1, 3)
  let vIP = line_edge(4, 6)
  let vIM = line_edge(5, 7)
  let sBp = line_edge(0, 4)
  let sBm = line_edge(1, 5)
  let sTp = line_edge(2, 6)
  let sTm = line_edge(3, 7)
  let face = fn(
    edges : Array[(@step.Ref, Bool)],
    surface : @step.Ref,
    same : Bool,
  ) -> @step.Ref {
    let oriented = edges.map(fn(e) { ctx.oriented_edge(e.0, e.1) })
    let edge_loop_ref = ctx.edge_loop(oriented)
    ctx.advanced_face(
      [ctx.face_outer_bound(edge_loop_ref, true)],
      surface,
      same,
    )
  }
  let cylinder_at = fn(z : Double, rad : Double) -> @step.Ref {
    let center = hhwf_cp(ctx, xform.apply((0.0, 0.0, z)))
    let a2p = ctx.axis2_placement_3d(center, dir_up, dir_right)
    ctx.add(
      @repository.any_entity_cylindrical_surface(
        @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(rad)),
      ),
    )
  }
  let faces : Array[@step.Ref] = []
  // Outer cylinder, outward normal.
  faces.push(
    face(
      [(eB, true), (vOM, true), (eT, false), (vOP, false)],
      cylinder_at(0.0, g.ro),
      true,
    ),
  )
  // Inner cylinder, normal toward the axis.
  faces.push(
    face(
      [(iB, false), (vIP, true), (iT, true), (vIM, false)],
      cylinder_at(0.0, g.ri),
      false,
    ),
  )
  // Slot walls.
  let slot_plus = hhwf_plane(
    ctx,
    xform.apply((0.0, g.half, 0.0)),
    xform.apply_dir((0.0, -1.0, 0.0)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  faces.push(
    face(
      [(vOP, true), (sTp, true), (vIP, false), (sBp, false)],
      slot_plus,
      true,
    ),
  )
  let slot_minus = hhwf_plane(
    ctx,
    xform.apply((0.0, -g.half, 0.0)),
    xform.apply_dir((0.0, 1.0, 0.0)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  faces.push(
    face(
      [(sBm, true), (vIM, true), (sTm, false), (vOM, false)],
      slot_minus,
      true,
    ),
  )
  // End faces.
  let bottom_plane = hhwf_plane(
    ctx,
    xform.apply((0.0, 0.0, 0.0)),
    xform.apply_dir((0.0, 0.0, -1.0)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  faces.push(
    face(
      [(eB, false), (sBp, true), (iB, true), (sBm, false)],
      bottom_plane,
      true,
    ),
  )
  let top_plane = hhwf_plane(
    ctx,
    xform.apply((0.0, 0.0, g.len)),
    xform.apply_dir((0.0, 0.0, 1.0)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  faces.push(
    face([(eT, true), (sTm, true), (iT, false), (sTp, false)], top_plane, true),
  )
  let _ = reverse
  faces
}

///|
/// slit_tube_mesh builds a visualization mesh of the slotted tube.
pub fn slit_tube_mesh(
  t : SlitTube,
  arc_segments~ : Int32 = 32,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match slit_tube_geometry(t) {
    Some(v) => v
    None => return ([], [])
  }
  let n = if arc_segments < 4 { 4 } else { arc_segments }
  let outline : Array[(Double, Double)] = []
  for k in 0..<=n {
    let a = g.delta_o +
      (2.0 * @math.PI - 2.0 * g.delta_o) *
      Double::from_int(k) /
      Double::from_int(n)
    outline.push((g.ro * @math.cos(a), g.ro * @math.sin(a)))
  }
  for k in 0..<=n {
    let a = 2.0 * @math.PI -
      g.delta_i -
      (2.0 * @math.PI - 2.0 * g.delta_i) *
      Double::from_int(k) /
      Double::from_int(n)
    outline.push((g.ri * @math.cos(a), g.ri * @math.sin(a)))
  }
  let m = outline.length()
  let verts : Array[Vec3] = []
  for p in outline {
    verts.push((p.0, p.1, 0.0))
  }
  for p in outline {
    verts.push((p.0, p.1, g.len))
  }
  let faces : Array[Array[Int32]] = []
  for i in 0..<m {
    let j = (i + 1) % m
    faces.push([i, j, m + j, m + i])
  }
  // Ear-clipped caps.
  let tris = ear_clip_2d(outline)
  for (a, b, c) in tris {
    faces.push([a, c, b])
    faces.push([m + a, m + b, m + c])
  }
  (verts, faces)
}

///|
fn ear_clip_2d(poly : Array[(Double, Double)]) -> Array[(Int32, Int32, Int32)] {
  let n = poly.length()
  let out : Array[(Int32, Int32, Int32)] = []
  if n < 3 {
    return out
  }
  let mut area = 0.0
  for i in 0..<n {
    let a = poly[i]
    let b = poly[(i + 1) % n]
    area = area + a.0 * b.1 - b.0 * a.1
  }
  let idx : Array[Int32] = []
  for i in 0..<n {
    if area >= 0.0 {
      idx.push(i)
    } else {
      idx.push(n - 1 - i)
    }
  }
  let cross = fn(a : Int32, b : Int32, c : Int32) -> Double {
    let pa = poly[a]
    let pb = poly[b]
    let pc = poly[c]
    (pb.0 - pa.0) * (pc.1 - pa.1) - (pb.1 - pa.1) * (pc.0 - pa.0)
  }
  let inside = fn(a : Int32, b : Int32, c : Int32, p : Int32) -> Bool {
    let d1 = cross(a, b, p)
    let d2 = cross(b, c, p)
    let d3 = cross(c, a, p)
    (d1 >= 0.0 && d2 >= 0.0 && d3 >= 0.0) ||
    (d1 <= 0.0 && d2 <= 0.0 && d3 <= 0.0)
  }
  while idx.length() > 3 {
    let k = idx.length()
    let mut clipped = false
    for i in 0..<k {
      let a = idx[(i + k - 1) % k]
      let b = idx[i]
      let c = idx[(i + 1) % k]
      if cross(a, b, c) <= 0.0 {
        continue
      }
      let mut any_inside = false
      for j in 0..<k {
        let p = idx[j]
        if p == a || p == b || p == c {
          continue
        }
        if inside(a, b, c, p) {
          any_inside = true
          break
        }
      }
      if any_inside {
        continue
      }
      out.push((a, b, c))
      let _ = idx.remove(i)
      clipped = true
      break
    }
    if !clipped {
      // Fallback fan, keeping the mesh closed.
      for i in 1..<(k - 1) {
        out.push((idx[0], idx[i], idx[i + 1]))
      }
      idx.clear()
      break
    }
  }
  if idx.length() == 3 {
    out.push((idx[0], idx[1], idx[2]))
  }
  out
}

///|
/// SlitTube::new builds a straight slotted tube.
pub fn SlitTube::new(
  outer_diameter_mm~ : Double,
  inner_diameter_mm~ : Double,
  length_mm~ : Double,
  slot_width_mm~ : Double,
) -> SlitTube {
  { outer_diameter_mm, inner_diameter_mm, length_mm, slot_width_mm, }
}

///|
/// SlitTube::as_shape wraps the intent as a `Shape`.
pub fn SlitTube::as_shape(self : SlitTube) -> Shape {
  Shape::SlitTube(self)
}
