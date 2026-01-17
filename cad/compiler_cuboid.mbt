///|
pub fn compile_cuboid(
  ctx : StepContext,
  node : SceneNode,
  cuboid : Cuboid,
  keep_curves~ : Bool,
  reverse? : Bool = false,
) -> Array[@step.Ref] {
  let sx = cuboid.sx
  let sy = cuboid.sy
  let sz = cuboid.sz

  // Corner points (mm)
  let pts_raw : Array[Vec3] = [
    (0.0, 0.0, 0.0),
    (sx, 0.0, 0.0),
    (sx, sy, 0.0),
    (0.0, sy, 0.0),
    (0.0, 0.0, sz),
    (sx, 0.0, sz),
    (sx, sy, sz),
    (0.0, sy, sz),
  ]

  // Transform points: Rotate then Translate
  let pts = pts_raw.map(fn(pt) {
    let (rx, ry, rz) = rotate_point(pt, node.rx, node.ry, node.rz)
    (rx + node.tx, ry + node.ty, rz + node.tz)
  })
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })

  // Vertex points
  let vp_refs = cp_refs.map(fn(cp_ref) { ctx.vertex_point(cp_ref) })

  // Common directions
  let dx_v = rotate_point((1.0, 0.0, 0.0), node.rx, node.ry, node.rz)
  let dy_v = rotate_point((0.0, 1.0, 0.0), node.rx, node.ry, node.rz)
  let dz_v = rotate_point((0.0, 0.0, 1.0), node.rx, node.ry, node.rz)
  let ndx_v = rotate_point((-1.0, 0.0, 0.0), node.rx, node.ry, node.rz)
  let ndy_v = rotate_point((0.0, -1.0, 0.0), node.rx, node.ry, node.rz)
  let ndz_v = rotate_point((0.0, 0.0, -1.0), node.rx, node.ry, node.rz)
  let dx = ctx.direction(dx_v.0, dx_v.1, dx_v.2)
  let dy = ctx.direction(dy_v.0, dy_v.1, dy_v.2)
  let dz = ctx.direction(dz_v.0, dz_v.1, dz_v.2)
  let ndx = ctx.direction(ndx_v.0, ndx_v.1, ndx_v.2)
  let ndy = ctx.direction(ndy_v.0, ndy_v.1, ndy_v.2)
  let ndz = ctx.direction(ndz_v.0, ndz_v.1, ndz_v.2)

  // Vectors
  let vx = ctx.vector(dx, 1.0)
  let vy = ctx.vector(dy, 1.0)
  let vz = ctx.vector(dz, 1.0)
  let vnx = ctx.vector(ndx, 1.0)
  let vny = ctx.vector(ndy, 1.0)

  // Edge definitions: (start_idx, end_idx, vector_ref)
  let edge_defs : Array[(Int, Int, @step.Ref)] = [
    (0, 1, vx),
    (1, 2, vy),
    (2, 3, vnx),
    (3, 0, vny), // bottom ring
    (4, 5, vx),
    (5, 6, vy),
    (6, 7, vnx),
    (7, 4, vny), // top ring
    (0, 4, vz),
    (1, 5, vz),
    (2, 6, vz),
    (3, 7, vz), // vertical pillars
  ]
  let edges = edge_defs.map(fn(def) {
    let (a, b, vec) = def
    let line_ref = ctx.line(cp_refs[a], vec)
    let ec_ref = ctx.edge_curve(vp_refs[a], vp_refs[b], line_ref, true)
    EdgeInfo::{ start: a, end: b, edge: ec_ref }
  })

  // Faces
  let face_refs : Array[@step.Ref] = [
    add_plane_face(ctx, edges, [0, 3, 2, 1], cp_refs[0], ndz, dx, reverse~),
    add_plane_face(ctx, edges, [4, 5, 6, 7], cp_refs[4], dz, dx, reverse~),
    add_plane_face(ctx, edges, [0, 1, 5, 4], cp_refs[0], ndy, dx, reverse~),
    add_plane_face(ctx, edges, [3, 7, 6, 2], cp_refs[3], dy, dx, reverse~),
    add_plane_face(ctx, edges, [0, 4, 7, 3], cp_refs[0], ndx, dy, reverse~),
    add_plane_face(ctx, edges, [1, 2, 6, 5], cp_refs[1], dx, dy, reverse~),
  ]
  face_refs
}
