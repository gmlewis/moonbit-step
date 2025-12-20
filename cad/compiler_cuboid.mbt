///|
pub fn compile_cuboid(
  ctx : StepContext,
  cuboid : Cuboid,
  tx : Double,
  ty : Double,
  tz : Double,
) -> @step.Ref {
  let sx = cuboid.sx
  let sy = cuboid.sy
  let sz = cuboid.sz

  // Corner points (mm)
  let pts : Array[(Double, Double, Double)] = [
    (tx + 0.0, ty + 0.0, tz + 0.0),
    (tx + sx, ty + 0.0, tz + 0.0),
    (tx + sx, ty + sy, tz + 0.0),
    (tx + 0.0, ty + sy, tz + 0.0),
    (tx + 0.0, ty + 0.0, tz + sz),
    (tx + sx, ty + 0.0, tz + sz),
    (tx + sx, ty + sy, tz + sz),
    (tx + 0.0, ty + sy, tz + sz),
  ]
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })

  // Vertex points
  let vp_refs = cp_refs.map(fn(cp_ref) {
    let vp = @topology.VertexPoint::new("", cp_ref)
    ctx.add(@repository.any_entity_vertex_point(vp))
  })

  // Common directions
  let dx = ctx.direction(1.0, 0.0, 0.0)
  let dy = ctx.direction(0.0, 1.0, 0.0)
  let dz = ctx.direction(0.0, 0.0, 1.0)
  let ndx = ctx.direction(-1.0, 0.0, 0.0)
  let ndy = ctx.direction(0.0, -1.0, 0.0)
  let ndz = ctx.direction(0.0, 0.0, -1.0)

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
    let line = @geometry.Line::new("", cp_refs[a], vec)
    let line_ref = ctx.add(@repository.any_entity_line(line))
    let ec = @topology.EdgeCurve::new(
      "",
      vp_refs[a],
      vp_refs[b],
      line_ref,
      true,
    )
    let ec_ref = ctx.add(@repository.any_entity_edge_curve(ec))
    EdgeInfo::{ start: a, end: b, edge: ec_ref }
  })

  // Faces
  let face_refs : Array[@step.Ref] = [
    // bottom (z=0), outward normal -Z
    add_plane_face(ctx, edges, [0, 3, 2, 1], cp_refs[0], ndz, dx),
    // top (z=sz), outward normal +Z
    add_plane_face(ctx, edges, [4, 5, 6, 7], cp_refs[4], dz, dx),
    // front (y=0), outward normal -Y
    add_plane_face(ctx, edges, [0, 1, 5, 4], cp_refs[0], ndy, dx),
    // back (y=sy), outward normal +Y
    add_plane_face(ctx, edges, [3, 7, 6, 2], cp_refs[3], dy, dx),
    // left (x=0), outward normal -X
    add_plane_face(ctx, edges, [0, 4, 7, 3], cp_refs[0], ndx, dy),
    // right (x=sx), outward normal +X
    add_plane_face(ctx, edges, [1, 2, 6, 5], cp_refs[1], dx, dy),
  ]

  // Closed shell and Brep
  let shell = @topology.ClosedShell::new("", face_refs)
  let shell_ref = ctx.add(@repository.any_entity_closed_shell(shell))
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  ctx.add(@repository.any_entity_manifold_solid_brep(brep))
}
