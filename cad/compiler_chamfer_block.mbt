///|
pub fn compile_calibration_chamfer_block(
  ctx : StepContext,
  node : SceneNode,
  block : CalibrationChamferBlock,
) -> @step.Ref {
  let l = block.length_mm
  let w = block.width_mm
  let h = block.height_mm
  let fillet_radius_mm = block.fillet_radius_mm
  let fillet_segments = block.fillet_segments
  let chamfer_size_mm = block.chamfer_size_mm

  // Build a stack of inset rectangles (offset) along Z.
  let rings : Array[(Double, Double)] = []
  rings.push((0.0, 0.0))
  if fillet_radius_mm > 0.0 {
    let r = fillet_radius_mm
    let start_z = h - r
    rings.push((start_z, 0.0))
    let segs = if fillet_segments <= 0 { 8 } else { fillet_segments }
    for i in 1..=segs {
      let phi = Double::from_int(i) * (@math.PI / 2.0) / Double::from_int(segs)
      let offset = r - r * @math.cos(phi)
      let z = h - r + r * @math.sin(phi)
      rings.push((z, offset))
    }
  } else if chamfer_size_mm > 0.0 {
    let c = chamfer_size_mm
    rings.push((h - c, 0.0))
    rings.push((h, c))
  } else {
    rings.push((h, 0.0))
  }

  // Points (mm)
  let pts_raw : Array[(Double, Double, Double)] = []
  for ring in rings {
    let (rz, ro) = ring
    let px0 = ro
    let px1 = l - ro
    let py0 = ro
    let py1 = w - ro
    pts_raw.push((px0, py0, rz))
    pts_raw.push((px1, py0, rz))
    pts_raw.push((px1, py1, rz))
    pts_raw.push((px0, py1, rz))
  }

  // Transform all points: Rotate then Translate
  let pts = pts_raw.map(fn(pt) {
    let (rx, ry, rz) = rotate_point(pt, node.rx, node.ry, node.rz)
    (rx + node.tx, ry + node.ty, rz + node.tz)
  })

  // Cartesian points
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })

  // Vertex points
  let vp_refs = cp_refs.map(fn(cp_ref) {
    let vp = @topology.VertexPoint::new("", cp_ref)
    ctx.add(@repository.any_entity_vertex_point(vp))
  })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map::new()
  let add_edge = fn(a : Int, b : Int) -> Unit {
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
    let line = @geometry.Line::new("", cp_refs[start], vec_ref)
    let line_ref = ctx.add(@repository.any_entity_line(line))
    let ec = @topology.EdgeCurve::new(
      "",
      vp_refs[start],
      vp_refs[end],
      line_ref,
      true,
    )
    let ec_ref = ctx.add(@repository.any_entity_edge_curve(ec))
    edges.push(EdgeInfo::{ start, end, edge: ec_ref })
  }

  // Per-ring perimeter edges
  for ri in 0..<rings.length() {
    let base = ri * 4
    add_edge(base + 0, base + 1)
    add_edge(base + 1, base + 2)
    add_edge(base + 2, base + 3)
    add_edge(base + 3, base + 0)
  }

  // Between-ring edges
  let between_count = rings.length() - 1
  for ri in 0..<between_count {
    let a = ri * 4
    let b = (ri + 1) * 4
    add_edge(a + 0, b + 0)
    add_edge(a + 1, b + 1)
    add_edge(a + 2, b + 2)
    add_edge(a + 3, b + 3)
  }

  // Faces
  let face_refs : Array[@step.Ref] = []
  let down_raw = rotate_point((0.0, 0.0, -1.0), node.rx, node.ry, node.rz)
  let up_raw = rotate_point((0.0, 0.0, 1.0), node.rx, node.ry, node.rz)
  face_refs.push(
    add_plane_face_oriented(ctx, edges, pts, cp_refs, [0, 3, 2, 1], down_raw),
  )
  let top_base = (rings.length() - 1) * 4
  face_refs.push(
    add_plane_face_oriented(
      ctx,
      edges,
      pts,
      cp_refs,
      [top_base + 0, top_base + 1, top_base + 2, top_base + 3],
      up_raw,
    ),
  )

  // Side faces
  for ri in 0..<between_count {
    let a = ri * 4
    let b = (ri + 1) * 4
    // Use cross product of transformed edges to get correct normal for each side
    let side_normals = [
      v_norm(
        v_cross(v_sub(pts[a + 1], pts[a + 0]), v_sub(pts[b + 0], pts[a + 0])),
      ), // front
      v_norm(
        v_cross(v_sub(pts[a + 2], pts[a + 1]), v_sub(pts[b + 1], pts[a + 1])),
      ), // right
      v_norm(
        v_cross(v_sub(pts[a + 3], pts[a + 2]), v_sub(pts[b + 2], pts[a + 2])),
      ), // back
      v_norm(
        v_cross(v_sub(pts[a + 0], pts[a + 3]), v_sub(pts[b + 3], pts[a + 3])),
      ), // left
    ]
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [a + 0, a + 1, b + 1, b + 0],
        side_normals[0],
      ),
    )
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [a + 1, a + 2, b + 2, b + 1],
        side_normals[1],
      ),
    )
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [a + 2, a + 3, b + 3, b + 2],
        side_normals[2],
      ),
    )
    face_refs.push(
      add_plane_face_oriented(
        ctx,
        edges,
        pts,
        cp_refs,
        [a + 3, a + 0, b + 0, b + 3],
        side_normals[3],
      ),
    )
  }

  // Solid
  let shell = @topology.ClosedShell::new("", face_refs)
  let shell_ref = ctx.add(@repository.any_entity_closed_shell(shell))
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  ctx.add(@repository.any_entity_manifold_solid_brep(brep))
}
