///|
// Native tapered extrusion.
//
// The large end lies at z = 0 and the small end at z = height_mm. Every section
// is the base profile scaled about the on-axis apex at z = apex_distance_mm.
// Because both ends are related by a homothety whose center is on the axis,
// each side face is a planar quad and the caps stay planar, so the whole solid
// is expressible with PLANE faces. The optional round bore is a real
// CYLINDRICAL_SURFACE whose radius does not scale with the outer profile.

///|
/// compile_conical_extrusion emits a planar-faced tapered solid.
fn compile_conical_extrusion(
  ctx : StepContext,
  node : SceneNode,
  e : ConicalExtrusion,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let profile = e.profile
  let height_mm = e.height_mm
  let apex = e.apex_distance_mm
  if height_mm <= 0.0 || apex <= height_mm || profile.outer.length() < 3 {
    return []
  }
  let k = (apex - height_mm) / apex

  // Normalize the winding: outer counter-clockwise, holes clockwise. The
  // positive scale factor preserves orientation, so the small end keeps it.
  let outer = if signed_area_2d(profile.outer) < 0.0 {
    profile.outer.rev()
  } else {
    profile.outer
  }
  let holes = profile.holes.map(fn(h) {
    if signed_area_2d(h) > 0.0 {
      h.rev()
    } else {
      h
    }
  })
  let scale = fn(p : Vec2) { (k * p.0, k * p.1) }
  let outer_t = outer.map(scale)
  let holes_t = holes.map(fn(h) { h.map(scale) })

  match e.round_bore {
    Some((center, diameter)) =>
      return compile_round_bore_prism(
        ctx,
        xform,
        outer,
        outer_t,
        holes,
        holes_t,
        0.0,
        height_mm,
        center,
        diameter,
        reverse~,
      )
    None => ()
  }

  // Flatten loops (outer first, then holes).
  let loops_b : Array[Array[Vec2]] = [
    outer,
    ..holes.filter(fn(h) { h.length() >= 3 }),
  ]
  let loops_t : Array[Array[Vec2]] = [
    outer_t,
    ..holes_t.filter(fn(h) { h.length() >= 3 }),
  ]

  // Build 3D points (large end then small end per loop).
  let pts_raw : Array[Vec3] = []
  let indices : Array[(Array[Int32], Array[Int32])] = []
  for i in 0..<loops_b.length() {
    let poly_b = loops_b[i]
    let poly_t = loops_t[i]
    let b = poly_b.map(fn(pt) {
      pts_raw.push((pt.0, pt.1, 0.0))
      pts_raw.length() - 1
    })
    let t = poly_t.map(fn(pt) {
      pts_raw.push((pt.0, pt.1, height_mm))
      pts_raw.length() - 1
    })
    indices.push((b, t))
  }

  // Transform all points: Rotate then Translate (parent applied last).
  let pts = pts_raw.map(fn(pt) { xform.apply(pt) })

  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })
  let vp_refs = cp_refs.map(fn(cp_ref) { ctx.vertex_point(cp_ref) })

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

  for pair in indices {
    let (b, t) = pair
    let n = b.length()
    for i in 0..<n {
      let j = (i + 1) % n
      add_edge(b[i], b[j])
      add_edge(t[i], t[j])
      add_edge(b[i], t[i])
    }
  }

  let face_refs : Array[@step.Ref] = []

  // Large and small caps (with holes).
  let (outer_b, outer_t) = indices[0]
  let hole_bs = indices.iter().drop(1).map(fn(lp) { lp.0 }).collect()
  let hole_ts = indices.iter().drop(1).map(fn(lp) { lp.1 }).collect()
  let down_raw = xform.apply_dir((0.0, 0.0, -1.0))
  let up_raw = xform.apply_dir((0.0, 0.0, 1.0))
  face_refs.push(
    add_plane_face_with_holes_oriented(
      ctx,
      edges,
      pts,
      cp_refs,
      outer_b,
      hole_bs,
      down_raw,
      reverse~,
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
      up_raw,
      reverse~,
    ),
  )

  // Side faces.
  for pair in indices {
    let (b, t) = pair
    let n = b.length()
    for i in 0..<n {
      let j = (i + 1) % n
      let p0 = pts[b[i]]
      let p1 = pts[b[j]]
      let p2 = pts[t[i]]
      let v1 = v_sub(p1, p0)
      let v2 = v_sub(p2, p0)
      let expected = v_norm(v_cross(v1, v2))
      face_refs.push(
        add_plane_face_oriented(
          ctx,
          edges,
          pts,
          cp_refs,
          [b[i], b[j], t[j], t[i]],
          expected,
          reverse~,
        ),
      )
    }
  }
  face_refs
}
