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
    return { id: { value: 0 } }
  }
  let z0 = tz
  let z1 = tz + height_mm

  // Flatten loops (outer first, then holes).
  let loops : Array[Array[(Double, Double)]] = [profile.outer]
  for hole in profile.holes {
    if hole.length() >= 3 {
      loops.push(hole)
    }
  }

  // Build 3D points (bottom then top per loop).
  let pts : Array[(Double, Double, Double)] = []
  let loop_indices = loops.map(fn(poly) {
    let b = poly.map(fn(pt) {
      let (px, py) = pt
      pts.push((tx + px, ty + py, z0))
      pts.length() - 1
    })
    let t = poly.map(fn(pt) {
      let (px, py) = pt
      pts.push((tx + px, ty + py, z1))
      pts.length() - 1
    })
    (b, t)
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
    edges.push(EdgeInfo::{ start, end, edge: ec_ref })
  }

  // Per-loop perimeter + vertical edges
  for loop_pair in loop_indices {
    let (b, t) = loop_pair
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
  let (outer_b, outer_t) = loop_indices[0]
  let hole_bs : Array[Array[Int]] = []
  let hole_ts : Array[Array[Int]] = []
  for i in 1..<loop_indices.length() {
    let (hb, ht) = loop_indices[i]
    hole_bs.push(hb)
    hole_ts.push(ht)
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
  for loop_pair in loop_indices {
    let (b, t) = loop_pair
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
