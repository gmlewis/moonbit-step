///|
pub fn compile_extruded_profile(
  ctx : StepContext,
  node : SceneNode,
  extrusion : ExtrudedProfile,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let profile = extrusion.profile
  let height_mm = extrusion.height_mm
  if height_mm == 0.0 || profile.outer.length() < 3 {
    return []
  }

  // Normalize the winding: outer counter-clockwise, holes clockwise. Side-face
  // normals are derived from the loop direction, while the caps are oriented
  // from their expected outward normal; a clockwise outer loop made the two
  // disagree and left shared edges traversed in the same direction.
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

  match extrusion.round_bore {
    Some((center, diameter)) =>
      return compile_extruded_round_bore(
        ctx,
        xform,
        outer,
        holes,
        height_mm,
        center,
        diameter,
        reverse~,
      )
    None => ()
  }

  // Flatten loops (outer first, then holes).
  let loops : Array[Array[Vec2]] = [
    outer,
    ..holes.filter(fn(h) { h.length() >= 3 }),
  ]

  // Build 3D points (bottom then top per loop).
  let pts_raw : Array[Vec3] = []
  let loop_indices = loops.map(fn(poly) {
    let b = poly.map(fn(pt) {
      let (px, py) = pt
      pts_raw.push((px, py, 0.0))
      pts_raw.length() - 1
    })
    let t = poly.map(fn(pt) {
      let (px, py) = pt
      pts_raw.push((px, py, height_mm))
      pts_raw.length() - 1
    })
    (b, t)
  })

  // Transform all points: Rotate then Translate (parent applied last)
  let pts = pts_raw.map(fn(pt) { xform.apply(pt) })

  // Cartesian points
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })

  // Vertex points
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
  let hole_bs = loop_indices.iter().drop(1).map(fn(lp) { lp.0 }).collect()
  let hole_ts = loop_indices.iter().drop(1).map(fn(lp) { lp.1 }).collect()
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

  // Side faces
  for loop_pair in loop_indices {
    let (b, t) = loop_pair
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

///|
/// compile_extruded_round_bore emits an extruded polygon whose hole is an
/// analytic circular bore. The outer boundary and any polygonal holes keep
/// their planar faces; the bore is a real `CYLINDRICAL_SURFACE` bounded by
/// `CIRCLE` edges and a seam, with annular planar caps. This keeps a gear bore
/// analytic even though the tooth outline is sampled.
fn compile_extruded_round_bore(
  ctx : StepContext,
  xform : Transform,
  outer : Array[Vec2],
  holes : Array[Array[Vec2]],
  height_mm : Double,
  center : Vec2,
  diameter : Double,
  reverse~ : Bool = false,
) -> Array[@step.Ref] {
  let rb = diameter / 2.0
  if height_mm == 0.0 || outer.length() < 3 || rb <= 0.0 {
    return []
  }
  let pts_raw : Array[Vec3] = []
  let ob : Array[Int32] = outer.map(fn(p) {
    pts_raw.push((p.0, p.1, 0.0))
    pts_raw.length() - 1
  })
  let ot : Array[Int32] = outer.map(fn(p) {
    pts_raw.push((p.0, p.1, height_mm))
    pts_raw.length() - 1
  })
  let holes_b : Array[Array[Int32]] = []
  let holes_t : Array[Array[Int32]] = []
  for h in holes {
    holes_b.push(
      h.map(fn(p) {
        pts_raw.push((p.0, p.1, 0.0))
        pts_raw.length() - 1
      }),
    )
    holes_t.push(
      h.map(fn(p) {
        pts_raw.push((p.0, p.1, height_mm))
        pts_raw.length() - 1
      }),
    )
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
  let loop_pairs : Array[(Array[Int32], Array[Int32])] = [(ob, ot)]
  for i in 0..<holes_b.length() {
    loop_pairs.push((holes_b[i], holes_t[i]))
  }
  for pair in loop_pairs {
    let (b, t) = pair
    let n = b.length()
    for i in 0..<n {
      let j = (i + 1) % n
      add_edge(b[i], b[j])
      add_edge(t[i], t[j])
      add_edge(b[i], t[i])
    }
  }
  // Analytic bore.
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let p_b = xform.apply((center.0, center.1, 0.0))
  let p_t = xform.apply((center.0, center.1, height_mm))
  let cp_b = ctx.cartesian_point(p_b.0, p_b.1, p_b.2)
  let cp_t = ctx.cartesian_point(p_t.0, p_t.1, p_t.2)
  let a2p_b = ctx.axis2_placement_3d(cp_b, dir_up, dir_right)
  let a2p_t = ctx.axis2_placement_3d(cp_t, dir_up, dir_right)
  let radius = @step.fmt_num(rb)
  let circle_b = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_b, radius)),
  )
  let circle_t = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_t, radius)),
  )
  let cylinder = ctx.add(
    @repository.any_entity_cylindrical_surface(
      @geometry.CylindricalSurface::new("", a2p_b, radius),
    ),
  )
  let seam_b = xform.apply((center.0 + rb, center.1, 0.0))
  let seam_t = xform.apply((center.0 + rb, center.1, height_mm))
  let cp_sb = ctx.cartesian_point(seam_b.0, seam_b.1, seam_b.2)
  let cp_st = ctx.cartesian_point(seam_t.0, seam_t.1, seam_t.2)
  let vp_sb = ctx.vertex_point(cp_sb)
  let vp_st = ctx.vertex_point(cp_st)
  let seam = ctx.edge_curve(
    vp_sb,
    vp_st,
    ctx.line(cp_sb, ctx.vector(dir_up, 1.0)),
    true,
  )
  let e_b = ctx.edge_curve(vp_sb, vp_sb, circle_b, true)
  let e_t = ctx.edge_curve(vp_st, vp_st, circle_t, true)
  let lateral_loop = ctx.edge_loop([
    ctx.oriented_edge(seam, true),
    ctx.oriented_edge(e_t, true),
    ctx.oriented_edge(seam, false),
    ctx.oriented_edge(e_b, false),
  ])
  let face_refs : Array[@step.Ref] = []
  face_refs.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(lateral_loop, true)],
      cylinder,
      reverse,
    ),
  )
  let bottom_hole = ctx.edge_loop([ctx.oriented_edge(e_b, true)])
  let top_hole = ctx.edge_loop([ctx.oriented_edge(e_t, false)])
  // The bottom cap is viewed from -Z, so its outer loop and every hole cycle
  // are reversed; the top cap keeps the normalized winding.
  let bottom_holes : Array[@step.Ref] = [bottom_hole]
  for hole_b in holes_b {
    bottom_holes.push(face_loop(ctx, edges, hole_b.rev()))
  }
  let top_holes : Array[@step.Ref] = [top_hole]
  for hole_t in holes_t {
    top_holes.push(face_loop(ctx, edges, hole_t))
  }
  face_refs.push(
    add_plane_face_with_edge_loops(
      ctx,
      edges,
      pts,
      cp_refs,
      ob,
      bottom_holes,
      down,
      reverse~,
    ),
  )
  face_refs.push(
    add_plane_face_with_edge_loops(
      ctx,
      edges,
      pts,
      cp_refs,
      ot,
      top_holes,
      up,
      reverse~,
    ),
  )
  for pair in loop_pairs {
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

///|
/// signed_area_2d returns the signed area of a polygon: positive when wound
/// counter-clockwise in the XY plane.
fn signed_area_2d(poly : Array[Vec2]) -> Double {
  let n = poly.length()
  if n < 3 {
    return 0.0
  }
  let mut area = 0.0
  for i in 0..<n {
    let (x0, y0) = poly[i]
    let (x1, y1) = poly[(i + 1) % n]
    area = area + x0 * y1 - x1 * y0
  }
  area / 2.0
}
