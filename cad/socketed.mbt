///|
/// SocketGeometry is the resolved geometry of a `SocketedSolid` pocket.
pub(all) struct SocketGeometry {
  top_z : Double
  top_radius : Double
  nominal_radius : Double
  top_hex_radius : Double
  mid_z : Double
  floor_z : Double
  lead : Double
  across_flats : Double
  rotation_deg : Double
}

///|
/// SocketedSolid::new builds a revolved body with a blind hexagonal socket.
///
/// `across_flats_mm` is the socket width across flats. `socket_floor_z_mm` is
/// the absolute local height of the socket floor. `lead_in_mm` is the optional
/// parallel 45-degree break on the six socket flats.
pub fn SocketedSolid::new(
  body : RevolvedProfile,
  across_flats_mm : Double,
  socket_floor_z_mm : Double,
  lead_in_mm~ : Double = 0.0,
  rotation_deg~ : Double = 30.0,
) -> SocketedSolid {
  { body, across_flats_mm, socket_floor_z_mm, lead_in_mm, rotation_deg, }
}

///|
/// SocketedSolid::body_segments returns the revolved body profile chain so
/// callers and tests can verify the underlying solid of revolution.
pub fn SocketedSolid::body_segments(self : SocketedSolid) -> Array[RevSegment] {
  self.body.segments
}

///|
/// SocketedSolid::as_shape wraps the intent as a `Shape`.
pub fn SocketedSolid::as_shape(self : SocketedSolid) -> Shape {
  Shape::SocketedSolid(self)
}

///|
fn socket_clamp01(v : Double) -> Double {
  if v < 0.0 {
    0.0
  } else if v > 1.0 {
    1.0
  } else {
    v
  }
}

///|
/// socketed_geometry resolves the body's flat top and the socket dimensions.
///
/// The body must be a canonical closed-on-axis `RevolvedProfile` (positive
/// signed area) whose last segment is the radial flat top cap ending on the
/// axis. Every shipped `SocketedSolid` is built that way.
fn socketed_geometry(s : SocketedSolid) -> SocketGeometry? {
  match s.body.validate() {
    Err(_) => return None
    Ok(_) => ()
  }
  let segs = s.body.segments
  let n = segs.length()
  if n < 2 || rev_profile_signed_area(segs) <= 0.0 {
    return None
  }
  let (top_radius, top_z) = match segs[n - 1] {
    RevLine(a, b) =>
      if b.0.abs() > 1.0e-9 || (a.1 - b.1).abs() > 1.0e-9 || a.0 <= 0.0 {
        return None
      } else {
        (a.0, b.1)
      }
    RevArc(_, _, _) => return None
  }
  let af = s.across_flats_mm
  let depth = top_z - s.socket_floor_z_mm
  if af <= 0.0 || depth <= 0.0 {
    return None
  }
  let nominal = af / Double::sqrt(3.0)
  let lead = if s.lead_in_mm > 0.0 {
    let cap = depth / 2.0
    if s.lead_in_mm < cap {
      s.lead_in_mm
    } else {
      cap
    }
  } else {
    0.0
  }
  let mid_z = top_z - lead
  let top_hex = nominal + lead / @math.cos(@math.PI / 6.0)
  if top_hex >= top_radius - 1.0e-9 {
    return None
  }
  Some({
    top_z,
    top_radius,
    nominal_radius: nominal,
    top_hex_radius: top_hex,
    mid_z,
    floor_z: s.socket_floor_z_mm,
    lead,
    across_flats: af,
    rotation_deg: s.rotation_deg,
  })
}

///|
/// socketed_pocket_area returns the exact pocket cross-section area at `z`.
fn socketed_pocket_area(g : SocketGeometry, z : Double) -> Double {
  if z < g.floor_z - 1.0e-12 || z > g.top_z + 1.0e-12 {
    return 0.0
  }
  let lead_span = g.top_z - g.mid_z
  let t = if lead_span > 1.0e-12 {
    socket_clamp01((z - g.mid_z) / lead_span)
  } else {
    0.0
  }
  let af_z = g.across_flats + 2.0 * g.lead * t
  Double::sqrt(3.0) / 2.0 * af_z * af_z
}

///|
/// socketed_pocket_volume_centroid integrates the pocket exactly. The area is
/// linear in the frustum scale and therefore quadratic in `z`; Simpson's rule
/// is exact for the volume and (up to cubic) for the first moment.
fn socketed_pocket_volume_centroid(g : SocketGeometry) -> (Double, Double) {
  let mut volume = 0.0
  let mut moment = 0.0
  let add_span = fn(z0 : Double, z1 : Double) -> Unit {
    if z1 <= z0 + 1.0e-12 {
      return
    }
    let zm = (z0 + z1) / 2.0
    let a0 = socketed_pocket_area(g, z0)
    let am = socketed_pocket_area(g, zm)
    let a1 = socketed_pocket_area(g, z1)
    volume = volume + (z1 - z0) / 6.0 * (a0 + 4.0 * am + a1)
    moment = moment + (z1 - z0) / 6.0 * (z0 * a0 + 4.0 * zm * am + z1 * a1)
  }
  add_span(g.floor_z, g.mid_z)
  add_span(g.mid_z, g.top_z)
  if volume <= 1.0e-12 {
    (0.0, 0.0)
  } else {
    (volume, moment / volume)
  }
}

///|
/// SocketedSolid::volume returns the exact solid volume in the local frame.
pub fn SocketedSolid::volume(self : SocketedSolid) -> Double {
  let (body_volume, _zc) = an_rev_volume_centroid(self.body)
  match socketed_geometry(self) {
    Some(g) => {
      let (void_volume, _vz) = socketed_pocket_volume_centroid(g)
      let v = body_volume - void_volume
      if v < 0.0 {
        0.0
      } else {
        v
      }
    }
    None => 0.0
  }
}

///|
/// SocketedSolid::centroid returns the exact centroid in the local frame.
pub fn SocketedSolid::centroid(self : SocketedSolid) -> Vec3 {
  let (body_volume, body_z) = an_rev_volume_centroid(self.body)
  match socketed_geometry(self) {
    Some(g) => {
      let (void_volume, void_z) = socketed_pocket_volume_centroid(g)
      let v = body_volume - void_volume
      if v <= 1.0e-12 {
        (0.0, 0.0, 0.0)
      } else {
        (0.0, 0.0, (body_volume * body_z - void_volume * void_z) / v)
      }
    }
    None => (0.0, 0.0, 0.0)
  }
}

///|
/// socketed_band resolves one revolved profile segment into a `RevBandInfo`.
fn socketed_band(seg : RevSegment) -> RevBandInfo {
  match seg {
    RevLine(a, b) => {
      let info : RevBandInfo = {
        a,
        b,
        center: None,
        sample: ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0),
        normal: rev_line_normal(a, b),
        radial: (a.1 - b.1).abs() < 1.0e-9,
        axial: (a.0 - b.0).abs() < 1.0e-9,
      }
      info
    }
    RevArc(a, b, c) => {
      let (sample, normal) = rev_arc_sample_normal(a, b, c)
      let info : RevBandInfo = {
        a,
        b,
        center: Some(c),
        sample,
        normal,
        radial: false,
        axial: false,
      }
      info
    }
  }
}

///|
/// compile_socketed_solid emits one closed solid for a revolved body with a
/// blind hexagonal socket cut into its flat top.
///
/// Every revolved band except the flat top cap is compiled by the analytic
/// revolve compiler, so the body's cylinders, cones, spheres, and tori stay
/// analytic. The top cap is replaced by a planar annular face (outer circle,
/// inner socket rim), six planar socket walls, an optional ruled lead-in, and a
/// planar hexagonal floor. Shared edges are traversed once per adjacent face in
/// opposite directions, so the result is a single watertight shell.
pub fn compile_socketed_solid(
  ctx : StepContext,
  node : SceneNode,
  s : SocketedSolid,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let g = match socketed_geometry(s) {
    Some(v) => v
    None => return []
  }
  let axis_dir = xform.apply_dir((0.0, 0.0, 1.0))
  let ref_dir = xform.apply_dir((1.0, 0.0, 0.0))
  let circles : Map[String, RevCircle] = Map([])
  let faces : Array[@step.Ref] = []
  // Every revolved band except the final flat top cap.
  let segs = s.body.segments
  let n = segs.length()
  for i in 0..<(n - 1) {
    let band = socketed_band(segs[i])
    match
      rev_compile_band(ctx, xform, band, axis_dir, ref_dir, circles, reverse~) {
      Some(f) => faces.push(f)
      None => ()
    }
  }
  // The top circle was emitted (with reversed sense) by the last real band.
  let top_circle = rev_get_circle(ctx, xform, g.top_radius, g.top_z, circles)
  // Socket vertices: top ring, optional mid ring, floor ring.
  let top_pts : Array[Vec3] = []
  for k in 0..<6 {
    let ang = (g.rotation_deg + 60.0 * Double::from_int(k)) * @math.PI / 180.0
    top_pts.push(
      xform.apply(
        (
          g.top_hex_radius * @math.cos(ang),
          g.top_hex_radius * @math.sin(ang),
          g.top_z,
        ),
      ),
    )
  }
  let mid_pts : Array[Vec3] = []
  for k in 0..<6 {
    let ang = (g.rotation_deg + 60.0 * Double::from_int(k)) * @math.PI / 180.0
    mid_pts.push(
      xform.apply(
        (
          g.nominal_radius * @math.cos(ang),
          g.nominal_radius * @math.sin(ang),
          g.mid_z,
        ),
      ),
    )
  }
  let floor_pts : Array[Vec3] = []
  for k in 0..<6 {
    let ang = (g.rotation_deg + 60.0 * Double::from_int(k)) * @math.PI / 180.0
    floor_pts.push(
      xform.apply(
        (
          g.nominal_radius * @math.cos(ang),
          g.nominal_radius * @math.sin(ang),
          g.floor_z,
        ),
      ),
    )
  }
  let has_mid = g.lead > 1.0e-12
  let pts : Array[Vec3] = []
  pts.push_iter(top_pts.iter())
  if has_mid {
    pts.push_iter(mid_pts.iter())
  }
  pts.push_iter(floor_pts.iter())
  let cp_refs = pts.map(fn(p) {
    let (px, py, pz) = p
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
  // Index layout: top 0..5, optional mid 6..11, floor next.
  let mid_base = if has_mid { 6 } else { 0 }
  let floor_base = if has_mid { 12 } else { 6 }
  for k in 0..<6 {
    add_edge(k, (k + 1) % 6)
    add_edge(floor_base + k, floor_base + (k + 1) % 6)
    if has_mid {
      add_edge(mid_base + k, mid_base + (k + 1) % 6)
      add_edge(k, mid_base + k)
      add_edge(mid_base + k, floor_base + k)
    } else {
      add_edge(k, floor_base + k)
    }
  }
  // Top annulus: analytic outer circle, hexagonal inner rim. The outer circle
  // is traversed in the direction opposite to the adjacent revolved band.
  let outer_loop = ctx.edge_loop([ctx.oriented_edge(top_circle.edge, true)])
  let inner_idx : Array[Int32] = []
  for k in 0..<6 {
    inner_idx.push(5 - k)
  }
  let inner_loop = face_loop(ctx, edges, inner_idx)
  let top_origin = xform.apply((0.0, 0.0, g.top_z))
  let top_origin_cp = ctx.cartesian_point(
    top_origin.0,
    top_origin.1,
    top_origin.2,
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      top_origin_cp,
      axis_dir,
      ref_dir,
      outer_loop,
      [inner_loop],
      reverse~,
    ),
  )
  // Lead-in quads (ruled 45-degree break) if requested.
  if has_mid {
    for k in 0..<6 {
      let k2 = (k + 1) % 6
      let cycle = [k, k2, mid_base + k2, mid_base + k]
      let normal = v_norm(cycle_area_3d(pts, cycle))
      faces.push(
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
  // Socket walls.
  let wall_top_base = if has_mid { mid_base } else { 0 }
  for k in 0..<6 {
    let k2 = (k + 1) % 6
    let cycle = [
      wall_top_base + k,
      wall_top_base + k2,
      floor_base + k2,
      floor_base + k,
    ]
    let normal = v_norm(cycle_area_3d(pts, cycle))
    faces.push(
      add_plane_face_oriented(ctx, edges, pts, cp_refs, cycle, normal, reverse~),
    )
  }
  // Hexagonal socket floor, normal +Z (up into the pocket).
  let floor_cycle : Array[Int32] = []
  for k in 0..<6 {
    floor_cycle.push(floor_base + k)
  }
  faces.push(
    add_plane_face_oriented(
      ctx,
      edges,
      pts,
      cp_refs,
      floor_cycle,
      axis_dir,
      reverse~,
    ),
  )
  faces
}

///|
/// socketed_solid_mesh builds a visualization mesh of the revolved body with
/// the blind socket. It samples the socket boundary at the same angular steps
/// as the body so the annulus and walls close without T-junctions.
pub fn socketed_solid_mesh(
  s : SocketedSolid,
  angular_segments~ : Int32 = 48,
  arc_segments~ : Int32 = 12,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match socketed_geometry(s) {
    Some(v) => v
    None => return ([], [])
  }
  let k = if angular_segments < 8 { 8 } else { angular_segments }
  // Body profile without the top centre point.
  let profile = rev_profile_polyline(s.body, arc_segments~)
  let m = profile.length()
  let body_pts : Array[Vec2] = []
  if m > 0 && profile[m - 1].0 < 1.0e-9 {
    for i in 0..<(m - 1) {
      body_pts.push(profile[i])
    }
  } else {
    body_pts.push_iter(profile.iter())
  }
  let mb = body_pts.length()
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  // Revolve the body bands.
  for j in 0..<k {
    let th = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(k)
    for i in 0..<mb {
      let (r, z) = body_pts[i]
      verts.push((r * @math.cos(th), r * @math.sin(th), z))
    }
  }
  let idx = fn(j : Int32, i : Int32) -> Int32 { j * mb + i }
  for j in 0..<k {
    let jn = (j + 1) % k
    for i in 0..<(mb - 1) {
      let ra = body_pts[i].0
      let rb = body_pts[i + 1].0
      if ra < 1.0e-9 && rb < 1.0e-9 {
        continue
      } else if ra < 1.0e-9 {
        faces.push([idx(j, i), idx(jn, i + 1), idx(j, i + 1)])
      } else if rb < 1.0e-9 {
        faces.push([idx(j, i), idx(jn, i), idx(jn, i + 1)])
      } else {
        faces.push([idx(j, i), idx(jn, i), idx(jn, i + 1), idx(j, i + 1)])
      }
    }
  }
  // Socket boundary radius sampled at each angular step.
  let hex_radius = fn(radius : Double, th : Double) -> Double {
    let step = 2.0 * @math.PI / 6.0
    let rot = g.rotation_deg * @math.PI / 180.0
    let rel = th - rot
    let sector = @math.floor(rel / step)
    let loc = rel - sector * step
    radius * @math.cos(step / 2.0) / @math.cos(loc - step / 2.0)
  }
  let top_base = verts.length()
  for j in 0..<k {
    let th = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(k)
    let r = hex_radius(g.top_hex_radius, th)
    verts.push((r * @math.cos(th), r * @math.sin(th), g.top_z))
  }
  let mid_base = if g.lead > 1.0e-12 {
    let b = verts.length()
    for j in 0..<k {
      let th = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(k)
      let r = hex_radius(g.nominal_radius, th)
      verts.push((r * @math.cos(th), r * @math.sin(th), g.mid_z))
    }
    b
  } else {
    top_base
  }
  let floor_base = verts.length()
  for j in 0..<k {
    let th = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(k)
    let r = hex_radius(g.nominal_radius, th)
    verts.push((r * @math.cos(th), r * @math.sin(th), g.floor_z))
  }
  let top_outer = (mb - 1) * 1
  for j in 0..<k {
    let jn = (j + 1) % k
    // Annulus between the body top circle and the socket opening.
    faces.push([
      idx(j, top_outer),
      idx(jn, top_outer),
      top_base + jn,
      top_base + j,
    ])
    if mid_base != top_base {
      faces.push([top_base + j, top_base + jn, mid_base + jn, mid_base + j])
    }
    faces.push([mid_base + j, mid_base + jn, floor_base + jn, floor_base + j])
  }
  // Floor fan.
  let centre_index = verts.length()
  verts.push((0.0, 0.0, g.floor_z))
  for j in 0..<k {
    let jn = (j + 1) % k
    faces.push([centre_index, floor_base + j, floor_base + jn])
  }
  (verts, faces)
}
