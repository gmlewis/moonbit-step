///|
// glTF 2.0 exporter.
//
// The mesh is derived from the compiled B-Rep (not from `Shape`), so booleans,
// composite transforms, and analytic geometry all tessellate uniformly:
//
//   * PLANE faces: boundary loops are sampled, projected to the plane, and
//     triangulated with ear clipping (holes are bridged into the outer loop).
//   * CYLINDRICAL_SURFACE faces: treated as full 360-degree bands and sampled
//     at `gltf_segments` segments. The caps are ordinary circular PLANE faces.
//   * SURFACE_OF_LINEAR_EXTRUSION faces: bands over the swept curve, sampled at
//     `gltf_segments` points.
//
// Output coordinates are Z-up, matching the STEP convention used throughout
// this library. Viewers that expect Y-up can rotate the root node by -90
// degrees about X. Vertex positions are welded (1e-9 grid) so a closed solid
// produces a closed index mesh, and normals are area-weighted per welded
// vertex.

///|
/// gltf_segments is the fixed tessellation resolution for circular and
/// swept-curve bands. A `Cylinder` therefore emits 2*64 band triangles plus
/// two 64-gon caps (62 triangles each).
let gltf_segments : Int32 = 64

///|
/// GltfPrim is one node's welded triangle mesh plus its color.
priv struct GltfPrim {
  name : String
  color : Rgb
  positions : Array[Vec3]
  normals : Array[Vec3]
  indices : Array[Int32]
}

///|
/// MeshBuilder welds positions on a 1e-9 grid and accumulates face normals.
priv struct MeshBuilder {
  verts : Array[Vec3]
  normals : Array[Vec3]
  indices : Array[Int32]
  lookup : Map[String, Int32]
}

///|
fn MeshBuilder::new() -> MeshBuilder {
  { verts: [], normals: [], indices: [], lookup: Map([]), }
}

///|
fn weld_key(p : Vec3) -> String {
  let scale = 1.0e9
  let x = (p.0 * scale).round().to_int64()
  let y = (p.1 * scale).round().to_int64()
  let z = (p.2 * scale).round().to_int64()
  "\{x},\{y},\{z}"
}

///|
fn MeshBuilder::weld(self : MeshBuilder, p : Vec3) -> Int32 {
  let key = weld_key(p)
  match self.lookup.get(key) {
    Some(i) => i
    None => {
      let i = self.verts.length()
      self.verts.push(p)
      self.normals.push((0.0, 0.0, 0.0))
      self.lookup.set(key, i)
      i
    }
  }
}

///|
/// add_triangle emits a triangle whose winding matches `wanted`, accumulating
/// its geometric normal on the three welded vertices.
fn MeshBuilder::add_triangle(
  self : MeshBuilder,
  a : Vec3,
  b : Vec3,
  c : Vec3,
  wanted : Vec3,
) -> Unit {
  let mut n = v_cross(v_sub(b, a), v_sub(c, a))
  if v_len(n) < 1.0e-14 {
    return
  }
  let (b2, c2) = if v_len(wanted) > 0.0 && v_dot(n, wanted) < 0.0 {
    n = (-n.0, -n.1, -n.2)
    (c, b)
  } else {
    (b, c)
  }
  let nn = v_norm(n)
  let ia = self.weld(a)
  let ib = self.weld(b2)
  let ic = self.weld(c2)
  self.indices.push(ia)
  self.indices.push(ib)
  self.indices.push(ic)
  self.normals[ia] = v_add(self.normals[ia], nn)
  self.normals[ib] = v_add(self.normals[ib], nn)
  self.normals[ic] = v_add(self.normals[ic], nn)
}

///|
fn MeshBuilder::finalize(self : MeshBuilder) -> (Array[Vec3], Array[Vec3]) {
  let normals = self.normals.map(fn(n) {
    let len = v_len(n)
    if len < 1.0e-12 {
      (0.0, 0.0, 1.0)
    } else {
      (n.0 / len, n.1 / len, n.2 / len)
    }
  })
  (self.verts, normals)
}

///|
// Small 3D vector helpers (v_sub/v_cross/v_dot/v_len/v_norm come from
// geometry_helpers.mbt).
fn v_add(a : Vec3, b : Vec3) -> Vec3 {
  (a.0 + b.0, a.1 + b.1, a.2 + b.2)
}

///|
fn v_scale(a : Vec3, s : Double) -> Vec3 {
  (a.0 * s, a.1 * s, a.2 * s)
}

///|
// Small 2D helpers for planar triangulation.
fn sub2(a : Vec2, b : Vec2) -> Vec2 {
  (a.0 - b.0, a.1 - b.1)
}

///|
fn cross2(a : Vec2, b : Vec2) -> Double {
  a.0 * b.1 - a.1 * b.0
}

///|
fn dist2(a : Vec2, b : Vec2) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  dx * dx + dy * dy
}

///|
// Repository access helpers.
fn repo_get(ctx : StepContext, r : @step.Ref) -> @repository.AnyEntity {
  match ctx.entities.get(r.id.value) {
    Some(e) => e
    None => abort("glTF exporter: dangling entity reference #\{r.id.value}")
  }
}

///|
fn parse_num(s : String) -> Double {
  @string.parse_double(s) catch {
    _ => 0.0
  }
}

///|
fn point_of(ctx : StepContext, r : @step.Ref) -> Vec3 {
  match repo_get(ctx, r) {
    CartesianPoint(p) => {
      let c = p.coordinates
      (c[0], c[1], c[2])
    }
    _ => abort("glTF exporter: expected CARTESIAN_POINT")
  }
}

///|
fn direction_of(ctx : StepContext, r : @step.Ref) -> Vec3 {
  match repo_get(ctx, r) {
    Direction(d) => {
      let c = d.ratios
      (c[0], c[1], c[2])
    }
    _ => abort("glTF exporter: expected DIRECTION")
  }
}

///|
/// axis2_frame returns (origin, normalized axis, normalized ref direction).
fn axis2_frame(ctx : StepContext, r : @step.Ref) -> (Vec3, Vec3, Vec3) {
  match repo_get(ctx, r) {
    Axis2Placement3D(a) => {
      let o = point_of(ctx, a.location)
      let z = v_norm(direction_of(ctx, a.axis))
      let x = v_norm(direction_of(ctx, a.ref_direction))
      (o, z, x)
    }
    _ => abort("glTF exporter: expected AXIS2_PLACEMENT_3D")
  }
}

///|
fn vertex_pos(ctx : StepContext, r : @step.Ref) -> Vec3 {
  match repo_get(ctx, r) {
    VertexPoint(v) => point_of(ctx, v.vertex_geometry)
    _ => abort("glTF exporter: expected VERTEX_POINT")
  }
}

///|
/// clean_collinear_closed drops consecutive duplicates and interior collinear
/// vertices from a closed loop, so that a band sampled from the same curve and
/// the corresponding cap end up with identical boundary edges.
fn clean_collinear_closed(pts : Array[Vec3]) -> Array[Vec3] {
  let deduped : Array[Vec3] = []
  for p in pts {
    let dup = match deduped.last() {
      Some(q) => v_len(v_sub(p, q)) <= 1.0e-12
      None => false
    }
    if !dup {
      deduped.push(p)
    }
  }
  let mut out = deduped
  let mut changed = true
  while changed && out.length() > 3 {
    changed = false
    let n = out.length()
    let keep : Array[Vec3] = []
    for i in 0..<n {
      let prev = out[(i + n - 1) % n]
      let cur = out[i]
      let next = out[(i + 1) % n]
      let a = v_sub(cur, prev)
      let b = v_sub(next, cur)
      let la = v_len(a)
      let lb = v_len(b)
      let collinear = la > 0.0 &&
        lb > 0.0 &&
        v_len(v_cross(a, b)) / (la * lb) < 1.0e-9
      if collinear && v_dot(a, b) > 0.0 {
        changed = true
      } else {
        keep.push(cur)
      }
    }
    out = keep
  }
  out
}

///|
/// expand_knots materializes the full knot vector from multiplicities.
fn expand_knots(mults : Array[Int32], knots : Array[String]) -> Array[Double] {
  let u : Array[Double] = []
  for i in 0..<mults.length() {
    let v = parse_num(knots[i])
    for _ in 0..<mults[i] {
      u.push(v)
    }
  }
  u
}

///|
/// bspline_eval evaluates a B-spline curve at `t` with de Boor's algorithm.
fn bspline_eval(
  pts : Array[Vec3],
  p : Int32,
  u : Array[Double],
  t : Double,
) -> Vec3 {
  let n = pts.length()
  let mut k = p
  for i in p..<n {
    if u[i] <= t && t < u[i + 1] {
      k = i
    }
  }
  let d : Array[Vec3] = Array::make(p + 1, (0.0, 0.0, 0.0))
  for j in 0..<=p {
    d[j] = pts[k - p + j]
  }
  for r in 1..<=p {
    let mut j = p
    while j >= r {
      let denom = u[j + 1 + k - r] - u[j + k - p]
      let alpha = if denom == 0.0 { 0.0 } else { (t - u[j + k - p]) / denom }
      d[j] = v_add(v_scale(d[j - 1], 1.0 - alpha), v_scale(d[j], alpha))
      j = j - 1
    }
  }
  d[p]
}

///|
fn sample_bspline(
  ctx : StepContext,
  b : @geometry.BSplineCurveWithKnots,
  closed~ : Bool,
  along~ : Bool,
) -> Array[Vec3] {
  let p = b.degree
  let pts = b.control_points.map(fn(r) { point_of(ctx, r) })
  let u = expand_knots(b.knot_multiplicities, b.knots)
  let n = pts.length()
  if n < p + 1 || u.length() < n + p + 1 {
    return []
  }
  let t0 = u[p]
  let t1 = u[n]
  let m = gltf_segments
  let out : Array[Vec3] = []
  if closed {
    for i in 0..<m {
      let t = t0 + (t1 - t0) * i.to_double() / m.to_double()
      out.push(bspline_eval(pts, p, u, t))
    }
    let cleaned = clean_collinear_closed(out)
    if along {
      cleaned
    } else {
      cleaned.rev()
    }
  } else {
    for i in 0..<=m {
      let t = t0 + (t1 - t0) * i.to_double() / m.to_double()
      out.push(bspline_eval(pts, p, u, t))
    }
    if along {
      out
    } else {
      out.rev()
    }
  }
}

///|
fn sample_circle(
  ctx : StepContext,
  pos_ref : @step.Ref,
  rx : Double,
  ry : Double,
  start_pos : Vec3,
  end_pos : Vec3,
  closed~ : Bool,
  along~ : Bool,
) -> Array[Vec3] {
  let (o, a, x) = axis2_frame(ctx, pos_ref)
  let y = v_norm(v_cross(a, x))
  let angle = fn(p : Vec3) -> Double {
    let rel = v_sub(p, o)
    @math.atan2(v_dot(rel, y), v_dot(rel, x))
  }
  let point = fn(theta : Double) -> Vec3 {
    v_add(
      o,
      v_add(
        v_scale(x, rx * @math.cos(theta)),
        v_scale(y, ry * @math.sin(theta)),
      ),
    )
  }
  let m = gltf_segments
  let tau = 2.0 * @math.PI
  let out : Array[Vec3] = []
  if closed {
    let t0 = angle(start_pos)
    for i in 0..<m {
      let t = if along {
        t0 + tau * i.to_double() / m.to_double()
      } else {
        t0 - tau * i.to_double() / m.to_double()
      }
      out.push(point(t))
    }
    out
  } else {
    let ts = angle(start_pos)
    let te = angle(end_pos)
    let mut delta = te - ts
    if along {
      if delta <= 0.0 {
        delta = delta + tau
      }
    } else if delta >= 0.0 {
      delta = delta - tau
    }
    for i in 0..<=m {
      out.push(point(ts + delta * i.to_double() / m.to_double()))
    }
    out
  }
}

///|
/// sample_oriented_edge samples one oriented edge into ordered 3D points.
fn sample_oriented_edge(ctx : StepContext, oe_ref : @step.Ref) -> Array[Vec3] {
  let oe = match repo_get(ctx, oe_ref) {
    OrientedEdge(o) => o
    _ => abort("glTF exporter: expected ORIENTED_EDGE")
  }
  let ec = match repo_get(ctx, oe.edge_element) {
    EdgeCurve(e) => e
    _ => abort("glTF exporter: expected EDGE_CURVE")
  }
  let start = vertex_pos(ctx, ec.edge_start)
  let end = vertex_pos(ctx, ec.edge_end)
  let closed = ec.edge_start.id.value == ec.edge_end.id.value
  let along = oe.orientation == ec.same_sense
  match repo_get(ctx, ec.edge_geometry) {
    Line(_) => if oe.orientation { [start, end] } else { [end, start] }
    Circle(c) => {
      let r = parse_num(c.radius_literal)
      sample_circle(ctx, c.position, r, r, start, end, closed~, along~)
    }
    Ellipse(e) => {
      let rx = parse_num(e.semi_axis_1_literal)
      let ry = parse_num(e.semi_axis_2_literal)
      sample_circle(ctx, e.position, rx, ry, start, end, closed~, along~)
    }
    BSplineCurveWithKnots(b) => sample_bspline(ctx, b, closed~, along~)
    Polyline(p) => {
      let pts = p.points.map(fn(r) { point_of(ctx, r) })
      if along {
        pts
      } else {
        pts.rev()
      }
    }
    _ => abort("glTF exporter: unsupported edge curve")
  }
}

///|
/// sample_loop concatenates a bound's oriented edges into one closed loop.
fn sample_loop(
  ctx : StepContext,
  loop_ref : @step.Ref,
  orientation : Bool,
) -> Array[Vec3] {
  let el = match repo_get(ctx, loop_ref) {
    EdgeLoop(e) => e
    _ => abort("glTF exporter: expected EDGE_LOOP")
  }
  let pts : Array[Vec3] = []
  for oe_ref in el.edges {
    for p in sample_oriented_edge(ctx, oe_ref) {
      let dup = match pts.last() {
        Some(q) => v_len(v_sub(p, q)) <= 1.0e-12
        None => false
      }
      if !dup {
        pts.push(p)
      }
    }
  }
  if pts.length() > 1 && v_len(v_sub(pts[0], pts[pts.length() - 1])) <= 1.0e-12 {
    let _ = pts.pop()
  }
  if orientation {
    pts
  } else {
    pts.rev()
  }
}

///|
/// loop_area returns the signed area of an index loop in 2D.
fn loop_area(pts : Array[Vec2], idx : Array[Int32]) -> Double {
  let n = idx.length()
  let mut area = 0.0
  for i in 0..<n {
    let p = pts[idx[i]]
    let q = pts[idx[(i + 1) % n]]
    area = area + (p.0 * q.1 - q.0 * p.1)
  }
  area / 2.0
}

///|
fn seg_proper(a : Vec2, b : Vec2, c : Vec2, d : Vec2) -> Bool {
  let d1 = cross2(sub2(b, a), sub2(c, a))
  let d2 = cross2(sub2(b, a), sub2(d, a))
  let d3 = cross2(sub2(d, c), sub2(a, c))
  let d4 = cross2(sub2(d, c), sub2(b, c))
  ((d1 > 0.0 && d2 < 0.0) || (d1 < 0.0 && d2 > 0.0)) &&
  ((d3 > 0.0 && d4 < 0.0) || (d3 < 0.0 && d4 > 0.0))
}

///|
fn segment_clear(
  pts : Array[Vec2],
  a : Int32,
  b : Int32,
  poly : Array[Int32],
  holes : Array[Array[Int32]],
  current_hole : Array[Int32],
) -> Bool {
  let pa = pts[a]
  let pb = pts[b]
  let n = poly.length()
  for i in 0..<n {
    let c = poly[i]
    let d = poly[(i + 1) % n]
    if c == a || d == a || c == b || d == b {
      continue
    }
    if seg_proper(pa, pb, pts[c], pts[d]) {
      return false
    }
  }
  for hole in holes {
    let m = hole.length()
    for i in 0..<m {
      let c = hole[i]
      let d = hole[(i + 1) % m]
      if c == a || d == a || c == b || d == b {
        continue
      }
      // Edges belonging to the current hole are allowed to touch the bridge
      // endpoint; skip edges incident to a or b above handles that.
      let _ = current_hole
      if seg_proper(pa, pb, pts[c], pts[d]) {
        return false
      }
    }
  }
  true
}

///|
fn point_in_tri(p : Vec2, a : Vec2, b : Vec2, c : Vec2) -> Bool {
  let eps = 1.0e-12
  let d1 = cross2(sub2(p, a), sub2(b, a))
  let d2 = cross2(sub2(p, b), sub2(c, b))
  let d3 = cross2(sub2(p, c), sub2(a, c))
  let has_neg = d1 < -eps || d2 < -eps || d3 < -eps
  let has_pos = d1 > eps || d2 > eps || d3 > eps
  !(has_neg && has_pos)
}

///|
fn is_ear(
  pts : Array[Vec2],
  poly : Array[Int32],
  prev : Int32,
  cur : Int32,
  next : Int32,
) -> Bool {
  let a = pts[prev]
  let b = pts[cur]
  let c = pts[next]
  if cross2(sub2(b, a), sub2(c, b)) <= 1.0e-12 {
    return false
  }
  for v in poly {
    if v == prev || v == cur || v == next {
      continue
    }
    if point_in_tri(pts[v], a, b, c) {
      return false
    }
  }
  true
}

///|
fn ear_clip(
  pts : Array[Vec2],
  poly_in : Array[Int32],
) -> Array[(Int32, Int32, Int32)] {
  let mut poly = poly_in.copy()
  if loop_area(pts, poly) < 0.0 {
    poly = poly.rev()
  }
  let out : Array[(Int32, Int32, Int32)] = []
  let limit = poly.length() * poly.length() + 10
  let mut steps = 0
  while poly.length() > 3 && steps < limit {
    steps = steps + 1
    let n = poly.length()
    let mut removed = false
    for i in 0..<n {
      let prev = poly[(i + n - 1) % n]
      let cur = poly[i]
      let next = poly[(i + 1) % n]
      if is_ear(pts, poly, prev, cur, next) {
        out.push((prev, cur, next))
        let rest : Array[Int32] = []
        for j in 0..<n {
          if j != i {
            rest.push(poly[j])
          }
        }
        poly = rest
        removed = true
        break
      }
    }
    if !removed {
      break
    }
  }
  if poly.length() == 3 {
    out.push((poly[0], poly[1], poly[2]))
  } else if poly.length() > 3 {
    for i in 1..<(poly.length() - 1) {
      out.push((poly[0], poly[i], poly[i + 1]))
    }
  }
  out
}

///|
/// triangulate_face_2d triangulates an outer loop with holes. Holes are bridged
/// into the outer loop (keyhole), then the resulting simple polygon is ear
/// clipped. Returned indices refer to `pts`.
fn triangulate_face_2d(
  pts : Array[Vec2],
  outer_in : Array[Int32],
  holes_in : Array[Array[Int32]],
) -> Array[(Int32, Int32, Int32)] {
  let mut outer = outer_in.copy()
  if loop_area(pts, outer) < 0.0 {
    outer = outer.rev()
  }
  let mut poly = outer
  for hole_in in holes_in {
    let mut hole = hole_in.copy()
    if hole.length() < 3 {
      continue
    }
    if loop_area(pts, hole) > 0.0 {
      hole = hole.rev()
    }
    let mut hi = 0
    for i in 1..<hole.length() {
      if pts[hole[i]].0 > pts[hole[hi]].0 {
        hi = i
      }
    }
    let hv = hole[hi]
    let mut best = 0
    let mut best_d = 1.0e300
    for j in 0..<poly.length() {
      let ov = poly[j]
      if segment_clear(pts, hv, ov, poly, holes_in, hole) {
        let d = dist2(pts[hv], pts[ov])
        if d < best_d {
          best_d = d
          best = j
        }
      }
    }
    let ov = poly[best]
    let ins : Array[Int32] = []
    let hn = hole.length()
    for k in 0..<hn {
      ins.push(hole[(hi + k) % hn])
    }
    ins.push(hv)
    ins.push(ov)
    let spliced : Array[Int32] = []
    for j in 0..<poly.length() {
      spliced.push(poly[j])
      if j == best {
        spliced.push_iter(ins.iter())
      }
    }
    poly = spliced
  }
  ear_clip(pts, poly)
}

///|
fn tessellate_plane(
  ctx : StepContext,
  af : @topology.AdvancedFace,
  plane : @geometry.Plane,
  mb : MeshBuilder,
) -> Unit {
  let (o, surface_n, x_surf) = axis2_frame(ctx, plane.position)
  let face_n = if af.same_sense { surface_n } else { v_scale(surface_n, -1.0) }
  let u = v_norm(x_surf)
  let v = v_norm(v_cross(face_n, u))
  let pts3d : Array[Vec3] = []
  let pts2d : Array[Vec2] = []
  let mut outer : Array[Int32] = []
  let holes : Array[Array[Int32]] = []
  for bound_ref in af.bounds {
    let (loop_ref, orientation, is_outer) = match repo_get(ctx, bound_ref) {
      FaceOuterBound(b) => (b.bound, b.orientation, true)
      FaceBound(b) => (b.bound, b.orientation, false)
      _ => abort("glTF exporter: expected FACE_BOUND")
    }
    let loop_pts = sample_loop(ctx, loop_ref, orientation)
    if loop_pts.length() < 3 {
      continue
    }
    let idx : Array[Int32] = []
    for p in loop_pts {
      let base = pts3d.length()
      pts3d.push(p)
      let rel = v_sub(p, o)
      pts2d.push((v_dot(rel, u), v_dot(rel, v)))
      idx.push(base)
    }
    if is_outer {
      outer = idx
    } else {
      holes.push(idx)
    }
  }
  if outer.length() < 3 {
    return
  }
  for tri in triangulate_face_2d(pts2d, outer, holes) {
    let (i0, i1, i2) = tri
    mb.add_triangle(pts3d[i0], pts3d[i1], pts3d[i2], face_n)
  }
}

///|
fn tessellate_cylinder(
  ctx : StepContext,
  af : @topology.AdvancedFace,
  cs : @geometry.CylindricalSurface,
  mb : MeshBuilder,
) -> Unit {
  let (o, a, x) = axis2_frame(ctx, cs.position)
  let y = v_norm(v_cross(a, x))
  let r = parse_num(cs.radius_literal)
  let mut s0 = 1.0e300
  let mut s1 = -1.0e300
  for bound_ref in af.bounds {
    let (loop_ref, orientation) = match repo_get(ctx, bound_ref) {
      FaceOuterBound(b) => (b.bound, b.orientation)
      FaceBound(b) => (b.bound, b.orientation)
      _ => abort("glTF exporter: expected FACE_BOUND")
    }
    for p in sample_loop(ctx, loop_ref, orientation) {
      let s = v_dot(v_sub(p, o), a)
      if s < s0 {
        s0 = s
      }
      if s > s1 {
        s1 = s
      }
    }
  }
  if s1 <= s0 {
    return
  }
  let nseg = gltf_segments
  let bottom : Array[Vec3] = []
  let top : Array[Vec3] = []
  for i in 0..<nseg {
    let th = 2.0 * @math.PI * i.to_double() / nseg.to_double()
    let radial = v_add(v_scale(x, @math.cos(th)), v_scale(y, @math.sin(th)))
    bottom.push(v_add(v_add(o, v_scale(radial, r)), v_scale(a, s0)))
    top.push(v_add(v_add(o, v_scale(radial, r)), v_scale(a, s1)))
  }
  let sign = if af.same_sense { 1.0 } else { -1.0 }
  for i in 0..<nseg {
    let j = (i + 1) % nseg
    let mth = 2.0 * @math.PI * (i.to_double() + 0.5) / nseg.to_double()
    let radial = v_add(v_scale(x, @math.cos(mth)), v_scale(y, @math.sin(mth)))
    let wanted = v_scale(v_norm(radial), sign)
    mb.add_triangle(bottom[i], bottom[j], top[j], wanted)
    mb.add_triangle(bottom[i], top[j], top[i], wanted)
  }
}

///|
fn sample_closed_curve(ctx : StepContext, curve_ref : @step.Ref) -> Array[Vec3] {
  match repo_get(ctx, curve_ref) {
    BSplineCurveWithKnots(b) => sample_bspline(ctx, b, closed=true, along=true)
    Circle(c) => {
      let r = parse_num(c.radius_literal)
      let (o, a, x) = axis2_frame(ctx, c.position)
      let y = v_norm(v_cross(a, x))
      let m = gltf_segments
      let out : Array[Vec3] = []
      for i in 0..<m {
        let th = 2.0 * @math.PI * i.to_double() / m.to_double()
        let radial = v_add(v_scale(x, @math.cos(th)), v_scale(y, @math.sin(th)))
        out.push(v_add(o, v_scale(radial, r)))
      }
      out
    }
    Polyline(p) => {
      let pts = p.points.map(fn(r) { point_of(ctx, r) })
      if pts.length() > 1 &&
        v_len(v_sub(pts[0], pts[pts.length() - 1])) <= 1.0e-12 {
        let _ = pts.pop()
      }
      pts
    }
    _ => abort("glTF exporter: unsupported swept curve")
  }
}

///|
fn tessellate_extrusion(
  ctx : StepContext,
  af : @topology.AdvancedFace,
  s : @geometry.SurfaceOfLinearExtrusion,
  mb : MeshBuilder,
) -> Unit {
  let (direction, magnitude) = match repo_get(ctx, s.extrusion_axis) {
    Vector(v) => (v_norm(direction_of(ctx, v.orientation)), v.magnitude)
    _ => abort("glTF exporter: expected VECTOR")
  }
  let vec = v_scale(direction, magnitude)
  let base = sample_closed_curve(ctx, s.swept_curve)
  let n = base.length()
  if n < 3 {
    return
  }
  let sign = if af.same_sense { 1.0 } else { -1.0 }
  for i in 0..<n {
    let j = (i + 1) % n
    let tangent = v_sub(base[j], base[i])
    if v_len(tangent) < 1.0e-14 {
      continue
    }
    let wanted = v_scale(v_norm(v_cross(tangent, vec)), sign)
    let bi = base[i]
    let bj = base[j]
    let ti = v_add(bi, vec)
    let tj = v_add(bj, vec)
    mb.add_triangle(bi, bj, tj, wanted)
    mb.add_triangle(bi, tj, ti, wanted)
  }
}

///|
fn tessellate_face(
  ctx : StepContext,
  face_ref : @step.Ref,
  mb : MeshBuilder,
) -> Unit {
  let af = match repo_get(ctx, face_ref) {
    AdvancedFace(a) => a
    _ => abort("glTF exporter: expected ADVANCED_FACE")
  }
  match repo_get(ctx, af.surface) {
    Plane(p) => tessellate_plane(ctx, af, p, mb)
    CylindricalSurface(c) => tessellate_cylinder(ctx, af, c, mb)
    SurfaceOfLinearExtrusion(s) => tessellate_extrusion(ctx, af, s, mb)
    _ =>
      abort(
        "glTF exporter: unsupported face surface for '\{af.name}'; only PLANE, CYLINDRICAL_SURFACE, and SURFACE_OF_LINEAR_EXTRUSION are tessellated",
      )
  }
}

///|
/// collect_faces_for_node compiles one top-level node exactly as
/// `Design::compile` does and returns its ADVANCED_FACE references.
fn collect_faces_for_node(
  ctx : StepContext,
  node : SceneNode,
) -> Array[@step.Ref] {
  match node.shape {
    Union(u) => {
      if u.nodes.length() == 0 {
        return []
      }
      let parent = Transform::from_node(node)
      if u.nodes.length() == 1 {
        return compile_node_shape(
          ctx,
          { ..u.nodes[0], name: node.name, },
          parent=Some(parent),
        )
      }
      let faces : Array[@step.Ref] = []
      for child in u.nodes {
        faces.push_iter(
          compile_node_shape(ctx, child, parent=Some(parent)).iter(),
        )
      }
      faces
    }
    Difference(d) => {
      let parent = Transform::from_node(node)
      if d.cutters.length() == 0 {
        return compile_node_shape(
          ctx,
          { ..d.base, name: node.name, },
          parent=Some(parent),
        )
      }
      let faces : Array[@step.Ref] = []
      faces.push_iter(
        compile_node_shape(ctx, d.base, parent=Some(parent)).iter(),
      )
      for cutter in d.cutters {
        faces.push_iter(
          compile_node_shape(ctx, cutter, reverse=true, parent=Some(parent)).iter(),
        )
      }
      faces
    }
    _ => compile_node_shape(ctx, node)
  }
}

///|
/// Design::to_gltf serializes the design as a self-contained glTF 2.0 JSON
/// document with an embedded base64 buffer, one mesh per `SceneNode`.
///
/// Coordinates are Z-up (STEP convention). Faces that are not PLANE,
/// CYLINDRICAL_SURFACE, or SURFACE_OF_LINEAR_EXTRUSION are rejected rather
/// than emitted as an invalid mesh.
pub fn Design::to_gltf(self : Design) -> String {
  let ctx = StepContext::new(snapping?=self.snapping)
  ctx.init_standard_context(self.name)
  let prims : Array[GltfPrim] = []
  for node in self.nodes {
    let mb = MeshBuilder::new()
    for face_ref in collect_faces_for_node(ctx, node) {
      tessellate_face(ctx, face_ref, mb)
    }
    if mb.indices.is_empty() {
      continue
    }
    let (positions, normals) = mb.finalize()
    prims.push({
      name: node.name,
      color: node.color,
      positions,
      normals,
      indices: mb.indices,
    })
  }
  build_gltf(prims)
}

///|
/// Design::to_gltf_file writes the design's glTF document to `out_path`.
pub async fn Design::to_gltf_file(self : Design, out_path : String?) -> Unit {
  write_text_file(self.to_gltf(), out_path)
}

///|
fn json_int(n : Int32) -> Json {
  Json::number(n.to_double(), repr=n.to_string())
}

///|
fn json_num(n : Double) -> Json {
  Json::number(n)
}

///|
fn json_str(s : String) -> Json {
  Json::string(s)
}

///|
fn json_obj(pairs : Array[(String, Json)]) -> Json {
  let m : Map[String, Json] = Map([])
  for p in pairs {
    m.set(p.0, p.1)
  }
  Json::object(m)
}

///|
fn vec_bounds(pts : Array[Vec3]) -> (Vec3, Vec3) {
  let mut mn = (1.0e300, 1.0e300, 1.0e300)
  let mut mx = (-1.0e300, -1.0e300, -1.0e300)
  for p in pts {
    if p.0 < mn.0 {
      mn = (p.0, mn.1, mn.2)
    }
    if p.1 < mn.1 {
      mn = (mn.0, p.1, mn.2)
    }
    if p.2 < mn.2 {
      mn = (mn.0, mn.1, p.2)
    }
    if p.0 > mx.0 {
      mx = (p.0, mx.1, mx.2)
    }
    if p.1 > mx.1 {
      mx = (mx.0, p.1, mx.2)
    }
    if p.2 > mx.2 {
      mx = (mx.0, mx.1, p.2)
    }
  }
  (mn, mx)
}

///|
fn pad_to_4(buf : @buffer.Buffer) -> Unit {
  while buf.length() % 4 != 0 {
    buf.write_byte(b'\x00')
  }
}

///|
fn buffer_view_json(off : Int32, len : Int32, target : Int32) -> Json {
  json_obj([
    ("buffer", json_int(0)),
    ("byteOffset", json_int(off)),
    ("byteLength", json_int(len)),
    ("target", json_int(target)),
  ])
}

///|
fn accessor_json(
  bv : Int32,
  component_type : Int32,
  count : Int32,
  ty : String,
  bounds : (Vec3, Vec3)?,
) -> Json {
  let pairs : Array[(String, Json)] = [
    ("bufferView", json_int(bv)),
    ("byteOffset", json_int(0)),
    ("componentType", json_int(component_type)),
    ("count", json_int(count)),
    ("type", json_str(ty)),
  ]
  match bounds {
    Some((mn, mx)) => {
      pairs.push(
        ("min", Json::array([json_num(mn.0), json_num(mn.1), json_num(mn.2)])),
      )
      pairs.push(
        ("max", Json::array([json_num(mx.0), json_num(mx.1), json_num(mx.2)])),
      )
    }
    None => ()
  }
  json_obj(pairs)
}

///|
fn build_gltf(prims : Array[GltfPrim]) -> String {
  let empty : Array[Byte] = []
  let buf = @buffer.from_array(empty)
  let buffer_views : Array[Json] = []
  let accessors : Array[Json] = []
  let meshes : Array[Json] = []
  let nodes : Array[Json] = []
  let materials : Array[Json] = []
  let scene_nodes : Array[Json] = []

  for pi in 0..<prims.length() {
    let prim = prims[pi]
    let nverts = prim.positions.length()
    // POSITION
    pad_to_4(buf)
    let pos_off = buf.length()
    for p in prim.positions {
      buf.write_float_le(Float::from_double(p.0))
      buf.write_float_le(Float::from_double(p.1))
      buf.write_float_le(Float::from_double(p.2))
    }
    let pos_bv = buffer_views.length()
    buffer_views.push(buffer_view_json(pos_off, buf.length() - pos_off, 34962))
    let (mn, mx) = vec_bounds(prim.positions)
    let pos_acc = accessors.length()
    accessors.push(accessor_json(pos_bv, 5126, nverts, "VEC3", Some((mn, mx))))
    // NORMAL
    pad_to_4(buf)
    let nrm_off = buf.length()
    for n in prim.normals {
      buf.write_float_le(Float::from_double(n.0))
      buf.write_float_le(Float::from_double(n.1))
      buf.write_float_le(Float::from_double(n.2))
    }
    let nrm_bv = buffer_views.length()
    buffer_views.push(buffer_view_json(nrm_off, buf.length() - nrm_off, 34962))
    let nrm_acc = accessors.length()
    accessors.push(accessor_json(nrm_bv, 5126, nverts, "VEC3", None))
    // indices
    pad_to_4(buf)
    let idx_off = buf.length()
    for i in prim.indices {
      buf.write_int_le(i)
    }
    let idx_bv = buffer_views.length()
    buffer_views.push(buffer_view_json(idx_off, buf.length() - idx_off, 34963))
    let idx_acc = accessors.length()
    accessors.push(
      accessor_json(idx_bv, 5125, prim.indices.length(), "SCALAR", None),
    )
    // mesh, material, node
    let mesh_index = meshes.length()
    meshes.push(
      json_obj([
        ("name", json_str(prim.name)),
        (
          "primitives",
          Json::array([
            json_obj([
              (
                "attributes",
                json_obj([
                  ("POSITION", json_int(pos_acc)),
                  ("NORMAL", json_int(nrm_acc)),
                ]),
              ),
              ("indices", json_int(idx_acc)),
              ("material", json_int(pi)),
              ("mode", json_int(4)),
            ]),
          ]),
        ),
      ]),
    )
    let color = prim.color
    materials.push(
      json_obj([
        ("name", json_str(prim.name)),
        (
          "pbrMetallicRoughness",
          json_obj([
            (
              "baseColorFactor",
              Json::array([
                json_num(color.r),
                json_num(color.g),
                json_num(color.b),
                json_num(1.0),
              ]),
            ),
            ("metallicFactor", json_num(0.0)),
            ("roughnessFactor", json_num(1.0)),
          ]),
        ),
      ]),
    )
    nodes.push(
      json_obj([("mesh", json_int(mesh_index)), ("name", json_str(prim.name))]),
    )
    scene_nodes.push(json_int(pi))
  }

  let b64 = @base64.std_encode2str(buf.to_bytes().to_fixedarray())
  let doc = json_obj([
    (
      "asset",
      json_obj([
        ("version", json_str("2.0")),
        ("generator", json_str("gmlewis/step/cad")),
      ]),
    ),
    ("scene", json_int(0)),
    ("scenes", Json::array([json_obj([("nodes", Json::array(scene_nodes))])])),
    ("nodes", Json::array(nodes)),
    ("meshes", Json::array(meshes)),
    ("materials", Json::array(materials)),
    ("accessors", Json::array(accessors)),
    ("bufferViews", Json::array(buffer_views)),
    (
      "buffers",
      Json::array([
        json_obj([
          ("byteLength", json_int(buf.length())),
          ("uri", json_str("data:application/octet-stream;base64," + b64)),
        ]),
      ]),
    ),
  ])
  doc.stringify()
}
