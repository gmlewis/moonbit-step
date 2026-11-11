///|
/// ChamferedPrism is a convex prism whose outer boundary is a stack of
/// parallel-inset rings, with an optional prismatic through-hole.
///
/// It is the generalisation of `CalibrationChamferBlock` needed for real
/// chamfers and fillets on hex nuts, screw heads, washers, and plates: each
/// ring is the base polygon offset inward by `inset`, placed at `z`. Consecutive
/// rings are joined by planar ruled quads (edges stay parallel under a uniform
/// parallel offset), and the ends are planar caps. With a through-hole the caps
/// become annuli and the hole gets vertical walls, so a blind socket is built
/// by placing this shape over a solid floor layer.
pub struct ChamferedPrism {
  base : Array[Vec2]
  levels : Array[(Double, Double)]
  hole : Array[Vec2]?
  /// Optional per-level hole profile. Each entry is `(z, inward_inset)` applied
  /// to `hole`, which is the largest (outermost) hole profile. The first and
  /// last `z` must equal the first and last outer level `z`, so the end caps
  /// close. This is how a real tapered hole (a socket lead-in chamfer or a
  /// countersink) is represented: the hole ring shrinks inward with depth.
  hole_levels : Array[(Double, Double)]?
}

///|
/// ChamferedPrism::new stores a ring stack without validating it. `levels` are
/// `(z, inset)` pairs with strictly increasing `z` and non-negative insets.
///
/// `hole_levels` optionally gives a `(z, inward_inset)` ring stack for the
/// hole; it makes a tapered hole such as a socket lead-in chamfer. Without it
/// the hole has vertical walls.
pub fn ChamferedPrism::new(
  base : Array[Vec2],
  levels : Array[(Double, Double)],
  hole? : Array[Vec2],
  hole_levels? : Array[(Double, Double)],
) -> ChamferedPrism {
  { base, levels, hole, hole_levels, }
}

///|
/// ChamferedPrism::from_chamfer builds a prism of `height` with an optional
/// chamfer at the bottom and top outer edges. `chamfer` is the parallel inset
/// at each face; `chamfer_depth` is the axial length of the chamfer.
pub fn ChamferedPrism::from_chamfer(
  base : Array[Vec2],
  height : Double,
  bottom_chamfer~ : Double = 0.0,
  top_chamfer~ : Double = 0.0,
  chamfer_depth~ : Double = 0.0,
  hole? : Array[Vec2],
) -> ChamferedPrism {
  let levels : Array[(Double, Double)] = []
  if bottom_chamfer > 0.0 && chamfer_depth > 0.0 {
    levels.push((0.0, bottom_chamfer))
    levels.push((chamfer_depth, 0.0))
  } else {
    levels.push((0.0, 0.0))
  }
  if top_chamfer > 0.0 && chamfer_depth > 0.0 {
    levels.push((height - chamfer_depth, 0.0))
    levels.push((height, top_chamfer))
  } else {
    levels.push((height, 0.0))
  }
  { base, levels, hole, hole_levels: None, }
}

///|
/// PrismError reports why a `ChamferedPrism` cannot be compiled.
pub(all) enum PrismError {
  PrismTooFewVertices
  PrismBadLevels
  PrismInsetTooLarge(Int32)
  PrismSelfIntersection
  PrismBadHole
}

///|
/// PrismError::message returns a human-readable diagnostic.
pub fn PrismError::message(self : PrismError) -> String {
  match self {
    PrismTooFewVertices => "chamfered prism base needs at least three vertices"
    PrismBadLevels => "chamfered prism levels must have increasing z"
    PrismInsetTooLarge(i) => "chamfered prism inset \{i} does not fit the base"
    PrismSelfIntersection => "chamfered prism inset ring self-intersects"
    PrismBadHole => "chamfered prism hole is invalid"
  }
}

///|
/// ChamferedPrism::validate checks the ring stack.
pub fn ChamferedPrism::validate(
  self : ChamferedPrism,
) -> Result[Unit, PrismError] {
  let n = self.base.length()
  if n < 3 || self.levels.length() < 2 {
    return Err(PrismTooFewVertices)
  }
  let mut prev_z = -1.0e300
  for i in 0..<self.levels.length() {
    let (z, inset) = self.levels[i]
    if z < prev_z - 1.0e-12 {
      return Err(PrismBadLevels)
    }
    prev_z = z
    if inset < -1.0e-12 {
      return Err(PrismInsetTooLarge(i))
    }
    let ring = match chamfer_inset(self.base, inset) {
      Some(r) => r
      None => return Err(PrismInsetTooLarge(i))
    }
    if !Profile2D::is_simple(ring) {
      return Err(PrismSelfIntersection)
    }
  }
  match self.hole {
    Some(h) =>
      if h.length() < 3 || !Profile2D::is_simple(h) {
        return Err(PrismBadHole)
      }
    None => ()
  }
  match self.hole_levels {
    Some(hls) =>
      match self.hole {
        None => return Err(PrismBadHole)
        Some(h) => {
          if hls.length() < 2 {
            return Err(PrismBadHole)
          }
          let z_first = self.levels[0].0
          let z_last = self.levels[self.levels.length() - 1].0
          if (hls[0].0 - z_first).abs() > 1.0e-9 ||
            (hls[hls.length() - 1].0 - z_last).abs() > 1.0e-9 {
            return Err(PrismBadHole)
          }
          let mut prev_z = -1.0e300
          let hccw = if polygon_area_2d(h) < 0.0 { h.rev() } else { h }
          for i in 0..<hls.length() {
            let (z, inset) = hls[i]
            if z < prev_z - 1.0e-12 {
              return Err(PrismBadHole)
            }
            prev_z = z
            if inset < -1.0e-12 {
              return Err(PrismBadHole)
            }
            match chamfer_inset(hccw, inset) {
              None => return Err(PrismBadHole)
              Some(ring) =>
                if !Profile2D::is_simple(ring) {
                  return Err(PrismBadHole)
                }
            }
          }
        }
      }
    None => ()
  }
  Ok(())
}

///|
/// chamfer_inset offsets a convex polygon inward by `c` along each edge.
fn chamfer_inset(profile : Array[Vec2], c : Double) -> Array[Vec2]? {
  if c <= 0.0 {
    return Some(profile)
  }
  let n = profile.length()
  if n < 3 {
    return None
  }
  let ccw = if polygon_area_2d(profile) < 0.0 { profile.rev() } else { profile }
  let out : Array[Vec2] = []
  for i in 0..<n {
    let prev = ccw[(i + n - 1) % n]
    let cur = ccw[i]
    let next = ccw[(i + 1) % n]
    let u1 = v2_norm(v2_sub(prev, cur))
    let u2 = v2_norm(v2_sub(next, cur))
    let theta = profile_corner_angle(u1, u2)
    if theta <= 1.0e-9 || theta >= @math.PI - 1.0e-9 {
      return None
    }
    let half = theta / 2.0
    let inset_dist = c / @math.sin(half)
    let bis = v2_norm((u1.0 + u2.0, u1.1 + u2.1))
    out.push((cur.0 + bis.0 * inset_dist, cur.1 + bis.1 * inset_dist))
  }
  if !is_convex_ccw(out) || polygon_area_2d(out) <= 0.0 {
    return None
  }
  // A valid inward offset must shrink the polygon and keep every point inside.
  if polygon_area_2d(out) >= polygon_area_2d(ccw) - 1.0e-12 {
    return None
  }
  for p in out {
    if !is_point_in_polygon(p, ccw) {
      return None
    }
  }
  Some(out)
}

///|
/// is_convex_ccw reports whether a counter-clockwise polygon is convex.
fn is_convex_ccw(pts : Array[Vec2]) -> Bool {
  let n = pts.length()
  if n < 3 {
    return false
  }
  for i in 0..<n {
    let a = pts[i]
    let b = pts[(i + 1) % n]
    let c = pts[(i + 2) % n]
    if profile_vertex_cross(a, b, c) < -1.0e-9 {
      return false
    }
  }
  true
}

///|
/// compile_chamfered_prism emits the ring-stack prism as one closed solid.
pub fn compile_chamfered_prism(
  ctx : StepContext,
  node : SceneNode,
  prism : ChamferedPrism,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  match prism.validate() {
    Err(_) => return []
    Ok(_) => ()
  }
  let base_raw = prism.base
  let base = if polygon_area_2d(base_raw) < 0.0 {
    base_raw.rev()
  } else {
    base_raw
  }
  let nc = base.length()
  let nl = prism.levels.length()
  // Build points: every level ring, then the hole rings at the first/last z.
  let pts_raw : Array[Vec3] = []
  let rings : Array[Array[Int32]] = []
  for li in 0..<nl {
    let (z, inset) = prism.levels[li]
    let ring = match chamfer_inset(base, inset) {
      Some(r) => r
      None => return []
    }
    let idxs : Array[Int32] = []
    for p in ring {
      idxs.push(pts_raw.length())
      pts_raw.push((p.0, p.1, z))
    }
    rings.push(idxs)
  }
  let z0 = prism.levels[0].0
  let z1 = prism.levels[nl - 1].0
  let hole_rings : Array[Array[Int32]] = []
  match prism.hole {
    Some(h) =>
      match prism.hole_levels {
        Some(hls) => {
          let hccw = if polygon_area_2d(h) < 0.0 { h.rev() } else { h }
          for level in hls {
            let (z, inset) = level
            let ring = match chamfer_inset(hccw, inset) {
              Some(r) => r.rev()
              None => return []
            }
            let idxs : Array[Int32] = []
            for p in ring {
              idxs.push(pts_raw.length())
              pts_raw.push((p.0, p.1, z))
            }
            hole_rings.push(idxs)
          }
        }
        None => {
          let hcw = if polygon_area_2d(h) > 0.0 { h.rev() } else { h }
          let idx0 : Array[Int32] = []
          for p in hcw {
            idx0.push(pts_raw.length())
            pts_raw.push((p.0, p.1, z0))
          }
          let idx1 : Array[Int32] = []
          for p in hcw {
            idx1.push(pts_raw.length())
            pts_raw.push((p.0, p.1, z1))
          }
          hole_rings.push(idx0)
          hole_rings.push(idx1)
        }
      }
    None => ()
  }
  let pts = pts_raw.map(fn(pt) { xform.apply(pt) })
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })
  let vp_refs = cp_refs.map(fn(cp) { ctx.vertex_point(cp) })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map([])
  let add_edge = fn(a : Int32, b : Int32) -> Unit {
    let key = if a < b { "\{a}:\{b}" } else { "\{b}:\{a}" }
    if seen.get(key).unwrap_or(false) {
      return
    }
    seen.set(key, true)
    let start = if a < b { a } else { b }
    let end = if a < b { b } else { a }
    let dir_raw = v_norm(v_sub(pts[end], pts[start]))
    let dir_ref = ctx.direction(dir_raw.0, dir_raw.1, dir_raw.2)
    let vec_ref = ctx.vector(dir_ref, 1.0)
    let line_ref = ctx.line(cp_refs[start], vec_ref)
    let ec_ref = ctx.edge_curve(vp_refs[start], vp_refs[end], line_ref, true)
    edges.push(EdgeInfo::{ start, end, edge: ec_ref, })
  }
  let connect_ring = fn(a : Array[Int32], b : Array[Int32]) -> Unit {
    let n = a.length()
    for k in 0..<n {
      add_edge(a[k], a[(k + 1) % n])
      add_edge(b[k], b[(k + 1) % n])
      add_edge(a[k], b[k])
    }
  }
  // Outer side edges between consecutive levels.
  for li in 0..<(nl - 1) {
    connect_ring(rings[li], rings[li + 1])
  }
  // Hole rings and vertical/ruled hole edges (one ring chain per level).
  let has_hole = prism.hole is Some(_)
  if has_hole {
    for hi in 0..<hole_rings.length() {
      let ring = hole_rings[hi]
      let nh = ring.length()
      for k in 0..<nh {
        add_edge(ring[k], ring[(k + 1) % nh])
      }
      if hi > 0 {
        let prev = hole_rings[hi - 1]
        for k in 0..<nh {
          add_edge(prev[k], ring[k])
        }
      }
    }
  }
  let face_refs : Array[@step.Ref] = []
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  // End caps.
  if has_hole {
    let hole_bottom = hole_rings[0]
    let hole_top = hole_rings[hole_rings.length() - 1]
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        rings[0],
        [hole_bottom],
        down,
        reverse~,
      ),
    )
    face_refs.push(
      add_plane_face_with_holes_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        rings[nl - 1],
        [hole_top],
        up,
        reverse~,
      ),
    )
  } else {
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        rings[0],
        down,
        reverse~,
      ),
    )
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        rings[nl - 1],
        up,
        reverse~,
      ),
    )
  }
  // Outer side quads; the plane normal is the actual quad normal, oriented
  // away from the axis.
  for li in 0..<(nl - 1) {
    let a = rings[li]
    let b = rings[li + 1]
    for k in 0..<nc {
      let k2 = (k + 1) % nc
      let cycle = [a[k], a[k2], b[k2], b[k]]
      let normal = prism_face_normal(pts, cycle, false)
      face_refs.push(
        add_plane_face_oriented(
          ctx,
          edges,
          pts,
          cp_refs,
          cycle,
          normal,
          reverse~,
        ),
      )
    }
  }
  // Hole walls; the plane normal points inward toward the axis. Consecutive
  // hole rings are joined by ruled quads, so a tapered hole (socket lead-in)
  // is a chain of planar ruled facets.
  if has_hole {
    for hi in 1..<hole_rings.length() {
      let a = hole_rings[hi - 1]
      let b = hole_rings[hi]
      let nh = a.length()
      for k in 0..<nh {
        let k2 = (k + 1) % nh
        let cycle = [a[k], a[k2], b[k2], b[k]]
        let normal = prism_face_normal(pts, cycle, true)
        face_refs.push(
          add_plane_face_oriented(
            ctx,
            edges,
            pts,
            cp_refs,
            cycle,
            normal,
            reverse~,
          ),
        )
      }
    }
  }
  face_refs
}

///|
/// prism_face_normal returns the quad's outward normal: away from the axis for
/// an outer face, toward the axis for a hole wall.
fn prism_face_normal(
  pts : Array[Vec3],
  cycle : Array[Int32],
  toward_axis : Bool,
) -> Vec3 {
  let centroid = ring_quad_centroid(pts, cycle)
  let av = cycle_area_3d(pts, cycle)
  let mut n = v_norm(av)
  let radial_dot = n.0 * centroid.0 + n.1 * centroid.1
  let want_outward = !toward_axis
  if want_outward && radial_dot < 0.0 {
    n = (-n.0, -n.1, -n.2)
  } else if !want_outward && radial_dot > 0.0 {
    n = (-n.0, -n.1, -n.2)
  }
  n
}

///|
fn ring_quad_centroid(pts : Array[Vec3], cycle : Array[Int32]) -> Vec3 {
  let n = cycle.length()
  let mut x = 0.0
  let mut y = 0.0
  let mut z = 0.0
  for i in cycle {
    let p = pts[i]
    x = x + p.0
    y = y + p.1
    z = z + p.2
  }
  let d = Double::from_int(n)
  (x / d, y / d, z / d)
}

///|
/// chamfered_prism_mesh builds a polygonal mesh approximation for the optional
/// Blender export. STEP output uses the analytic compiler, not this mesh.
pub fn chamfered_prism_mesh(
  prism : ChamferedPrism,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let base_raw = prism.base
  let base = if polygon_area_2d(base_raw) < 0.0 {
    base_raw.rev()
  } else {
    base_raw
  }
  let nc = base.length()
  let verts : Array[Vec3] = []
  let rings : Array[Array[Int32]] = []
  for level in prism.levels {
    let (z, inset) = level
    let ring = match chamfer_inset(base, inset) {
      Some(r) => r
      None => base
    }
    let idxs : Array[Int32] = []
    for p in ring {
      idxs.push(verts.length())
      verts.push((p.0, p.1, z))
    }
    rings.push(idxs)
  }
  let faces : Array[Array[Int32]] = []
  let nl = rings.length()
  for li in 0..<(nl - 1) {
    let a = rings[li]
    let b = rings[li + 1]
    for k in 0..<nc {
      let k2 = (k + 1) % nc
      faces.push([a[k], a[k2], b[k2], b[k]])
    }
  }
  if prism.hole is None {
    faces.push(rings[0].copy())
    faces.push(rings[nl - 1].rev())
  }
  (verts, faces)
}

///|
/// ChamferedPrism::as_shape wraps the prism as a `Shape`.
pub fn ChamferedPrism::as_shape(self : ChamferedPrism) -> Shape {
  Shape::ChamferedPrism(self)
}
