///|
pub fn compile_extruded_profile(
  ctx : StepContext,
  extrusion : ExtrudedProfile,
  tx : Double,
  ty : Double,
  tz : Double,
) -> @step.Ref {
  let profile = extrusion.profile
  let height_mm = extrusion.height_mm
  if height_mm == 0.0 || profile.outer.length() < 3 {
    // Should return a null or empty ref, but for now we follow old logic
    return { id: { value: 0 } }
  }
  let z0 = tz
  let z1 = tz + height_mm

  // Flatten loops (outer first, then holes).
  let loops : Array[Array[(Double, Double)]] = []
  loops.push(profile.outer)
  for i = 0; i < profile.holes.length(); i = i + 1 {
    if profile.holes[i].length() >= 3 {
      loops.push(profile.holes[i])
    }
  }

  // Build 3D points (bottom then top per loop).
  let pts : Array[(Double, Double, Double)] = []
  let loop_bottom : Array[Array[Int]] = []
  let loop_top : Array[Array[Int]] = []
  for poly in loops {
    let b : Array[Int] = []
    let t : Array[Int] = []
    for pt in poly {
      let (px, py) = pt
      pts.push((tx + px, ty + py, z0))
      b.push(pts.length() - 1)
    }
    for pt in poly {
      let (px, py) = pt
      pts.push((tx + px, ty + py, z1))
      t.push(pts.length() - 1)
    }
    loop_bottom.push(b)
    loop_top.push(t)
  }

  // Cartesian points
  let cp_refs : Array[@step.Ref] = []
  for pt in pts {
    let (px, py, pz) = pt
    cp_refs.push(ctx.cartesian_point(px, py, pz))
  }

  // Vertex points
  let vp_refs : Array[@step.Ref] = []
  for cp_ref in cp_refs {
    let vp = @topology.VertexPoint::new("", cp_ref)
    vp_refs.push(ctx.add(@repository.any_entity_vertex_point(vp)))
  }
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
    let dir_vec = v_norm(v_sub(pts[end], pts[start]))
    let dir_ref = ctx.direction(dir_vec.0, dir_vec.1, dir_vec.2)
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
    edges.push({ start, end, edge: ec_ref })
  }

  // Per-loop perimeter + vertical edges
  for li in 0..<loops.length() {
    let b = loop_bottom[li]
    let t = loop_top[li]
    let n = b.length()
    for i in 0..<n {
      let j = (i + 1) % n
      add_edge(b[i], b[j])
      add_edge(t[i], t[j])
      add_edge(b[i], t[i])
    }
  }

  // Faces
  let face_refs : Array[@step.Ref] = []

  // Bottom/top (with holes)
  let outer_b = loop_bottom[0]
  let outer_t = loop_top[0]
  let hole_bs : Array[Array[Int]] = []
  let hole_ts : Array[Array[Int]] = []
  for li in 1..<loops.length() {
    hole_bs.push(loop_bottom[li])
    hole_ts.push(loop_top[li])
  }
  face_refs.push(
    add_plane_face_with_holes_oriented(
      ctx,
      edges,
      pts,
      cp_refs,
      outer_b,
      hole_bs,
      (0.0, 0.0, -1.0),
    ),
  )
  face_refs.push(
    add_plane_face_with_holes_oriented(
      ctx,
      edges,
      pts,
      cp_refs,
      outer_t,
      hole_ts,
      (0.0, 0.0, 1.0),
    ),
  )

  // Side faces
  for li in 0..<loops.length() {
    let b = loop_bottom[li]
    let t = loop_top[li]
    let n = b.length()
    for i in 0..<n {
      let j = (i + 1) % n
      let (px0, py0, _) = pts[b[i]]
      let (px1, py1, _) = pts[b[j]]
      let dx = px1 - px0
      let dy = py1 - py0
      let expected = v_norm((dy, -dx, 0.0))
      face_refs.push(
        add_plane_face_oriented(
          ctx,
          edges,
          pts,
          cp_refs,
          [b[i], b[j], t[j], t[i]],
          expected,
        ),
      )
    }
  }

  // Solid
  let shell = @topology.ClosedShell::new("", face_refs)
  let shell_ref = ctx.add(@repository.any_entity_closed_shell(shell))
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  ctx.add(@repository.any_entity_manifold_solid_brep(brep))
}
