///|
// Hexagon head trimmed by a conical washer face. The top is a circle of
// radius across_flats/2, the chamfer is a 75-degree cone, and the flat/cone
// intersections are hyperbolas (the STEP reference topology).

///|
priv struct HHWFGeometry {
  rb : Double
  rt : Double
  k : Double
  zb : Double
  c : Double
  tan_alpha : Double
}

///|
fn hhwf_geometry(h : HexHeadWasherFace) -> HHWFGeometry? {
  let s = h.across_flats_mm
  let k = h.head_height_mm
  if s <= 0.0 || k <= 0.0 {
    return None
  }
  let rb = s / Double::sqrt(3.0)
  let rt = s / 2.0
  let tan_alpha = @math.tan(75.0 * @math.PI / 180.0)
  let c = (rb - rt) / tan_alpha
  let zb = k - c
  if zb <= 0.0 {
    return None
  }
  Some({ rb, rt, k, zb, c, tan_alpha, })
}

///|
fn hhwf_cp(ctx : StepContext, p : Vec3) -> @step.Ref {
  ctx.cartesian_point(p.0, p.1, p.2)
}

///|
fn hhwf_line_edge(
  ctx : StepContext,
  a_cp : @step.Ref,
  a_vp : @step.Ref,
  b_cp : @step.Ref,
  b_vp : @step.Ref,
  a : Vec3,
  b : Vec3,
) -> @step.Ref {
  let direction = v_norm(v_sub(b, a))
  let dir_ref = ctx.direction(direction.0, direction.1, direction.2)
  let vector_ref = ctx.vector(dir_ref, 1.0)
  ctx.edge_curve(a_vp, b_vp, ctx.line(a_cp, vector_ref), true)
}

///|
fn hhwf_circle_edge(
  ctx : StepContext,
  center : Vec3,
  radius : Double,
  a_cp : @step.Ref,
  a_vp : @step.Ref,
  b_cp : @step.Ref,
  b_vp : @step.Ref,
  same_sense : Bool,
  dir_up : @step.Ref,
  dir_right : @step.Ref,
) -> @step.Ref {
  let ccp = hhwf_cp(ctx, center)
  let a2p = ctx.axis2_placement_3d(ccp, dir_up, dir_right)
  let circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", a2p, @step.fmt_num(radius)),
    ),
  )
  ctx.edge_curve(a_vp, b_vp, circle, same_sense)
}

///|
fn hhwf_hyperbola_edge(
  ctx : StepContext,
  center : Vec3,
  axis : Vec3,
  reference : Vec3,
  semi_axis : Double,
  semi_imag : Double,
  a_vp : @step.Ref,
  b_vp : @step.Ref,
  same_sense : Bool,
) -> @step.Ref {
  let ccp = hhwf_cp(ctx, center)
  let axis_ref = ctx.direction(axis.0, axis.1, axis.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let a2p = ctx.axis2_placement_3d(ccp, axis_ref, ref_ref)
  let hyperbola = ctx.add(
    @repository.any_entity_hyperbola(
      @geometry.Hyperbola::new("", a2p, semi_axis, semi_imag),
    ),
  )
  ctx.edge_curve(a_vp, b_vp, hyperbola, same_sense)
}

///|
fn hhwf_hyperbola_polyline(
  ctx : StepContext,
  phi : Double,
  rt : Double,
  tan_alpha : Double,
  zb : Double,
  a_pos : Vec3,
  b_pos : Vec3,
  a_vp : @step.Ref,
  b_vp : @step.Ref,
  xform : Transform,
) -> @step.Ref {
  let tangent = (-@math.sin(phi), @math.cos(phi), 0.0)
  let c_at = fn(z : Double) -> Vec3 {
    xform.apply((rt * @math.cos(phi), rt * @math.sin(phi), z))
  }
  let a_flat = c_at(zb)
  let u0 = (a_pos.0 - a_flat.0) * tangent.0 + (a_pos.1 - a_flat.1) * tangent.1
  let sign = if u0 >= 0.0 { 1.0 } else { -1.0 }
  let n = 64
  let pts : Array[Vec3] = []
  for i in 0..<=n {
    let t = i.to_double() / n.to_double()
    let zz = zb + (b_pos.2 - zb) * t
    let w = b_pos.2 - zz
    let u = sign *
      Double::sqrt(2.0 * rt * tan_alpha * w + tan_alpha * tan_alpha * w * w)
    let c = c_at(zz)
    pts.push((c.0 + u * tangent.0, c.1 + u * tangent.1, c.2))
  }
  if a_pos.2 > b_pos.2 {
    let rev : Array[Vec3] = []
    for i in 0..<=n {
      rev.push(pts[n - i])
    }
    pts.clear()
    for p in rev {
      pts.push(p)
    }
  }
  let cps = pts.map(fn(p) { hhwf_cp(ctx, p) })
  let poly = @geometry.Polyline::new("", cps)
  let poly_ref = ctx.add(@repository.any_entity_polyline(poly))
  ctx.edge_curve(a_vp, b_vp, poly_ref, true)
}

///|
fn hhwf_plane(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
) -> @step.Ref {
  let origin_cp = hhwf_cp(ctx, origin)
  let axis_ref = ctx.direction(axis.0, axis.1, axis.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let a2p = ctx.axis2_placement_3d(origin_cp, axis_ref, ref_ref)
  ctx.add(@repository.any_entity_plane(@geometry.Plane::new("", a2p)))
}

///|
fn hhwf_cone(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
  radius : Double,
  semi_angle_deg : Double,
) -> @step.Ref {
  let origin_cp = hhwf_cp(ctx, origin)
  let axis_ref = ctx.direction(axis.0, axis.1, axis.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let a2p = ctx.axis2_placement_3d(origin_cp, axis_ref, ref_ref)
  let semi = @step.fmt_num(semi_angle_deg * @math.PI / 180.0)
  ctx.add(
    @repository.any_entity_conical_surface(
      @geometry.ConicalSurface::new("", a2p, @step.fmt_num(radius), semi),
    ),
  )
}

///|
fn hhwf_newell(points : Array[Vec3]) -> Vec3 {
  let mut nx = 0.0
  let mut ny = 0.0
  let mut nz = 0.0
  let n = points.length()
  for i in 0..<n {
    let a = points[i]
    let b = points[(i + 1) % n]
    nx = nx + (a.1 - b.1) * (a.2 + b.2)
    ny = ny + (a.2 - b.2) * (a.0 + b.0)
    nz = nz + (a.0 - b.0) * (a.1 + b.1)
  }
  v_norm((nx, ny, nz))
}

///|
fn hhwf_face(
  ctx : StepContext,
  edges : Array[(@step.Ref, Bool)],
  surface : @step.Ref,
  natural : Vec3,
  loop_points : Array[Vec3],
) -> @step.Ref {
  let oriented = edges.map(fn(e) { ctx.oriented_edge(e.0, e.1) })
  let edge_loop = ctx.edge_loop(oriented)
  let bound = ctx.face_outer_bound(edge_loop, true)
  let same = v_dot(hhwf_newell(loop_points), natural) >= 0.0
  ctx.advanced_face([bound], surface, same)
}

///|
/// compile_hex_head_washer_face emits the conical-washer-face hex head.
pub fn compile_hex_head_washer_face(
  ctx : StepContext,
  node : SceneNode,
  h : HexHeadWasherFace,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let g = match hhwf_geometry(h) {
    Some(g) => g
    None => return []
  }
  let xform = node_transform(node, parent)
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)

  let base_pos : Array[Vec3] = []
  let hex_top_pos : Array[Vec3] = []
  for i in 0..<6 {
    let a = 60.0 * i.to_double() * @math.PI / 180.0
    base_pos.push(xform.apply((g.rb * @math.cos(a), g.rb * @math.sin(a), 0.0)))
    hex_top_pos.push(
      xform.apply((g.rb * @math.cos(a), g.rb * @math.sin(a), g.zb)),
    )
  }
  let top_seam_pos = xform.apply((g.rt, 0.0, g.k))
  let base_cp = base_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let hex_cp = hex_top_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let top_cp = hhwf_cp(ctx, top_seam_pos)
  let base_vp = base_cp.map(fn(c) { ctx.vertex_point(c) })
  let hex_vp = hex_cp.map(fn(c) { ctx.vertex_point(c) })
  let top_vp = ctx.vertex_point(top_cp)

  let bottom_edges : Array[@step.Ref] = []
  let vertical_edges : Array[@step.Ref] = []
  let hex_top_edges : Array[@step.Ref] = []
  for i in 0..<6 {
    let j = (i + 1) % 6
    bottom_edges.push(
      hhwf_line_edge(
        ctx,
        base_cp[i],
        base_vp[i],
        base_cp[j],
        base_vp[j],
        base_pos[i],
        base_pos[j],
      ),
    )
    vertical_edges.push(
      hhwf_line_edge(
        ctx,
        base_cp[i],
        base_vp[i],
        hex_cp[i],
        hex_vp[i],
        base_pos[i],
        hex_top_pos[i],
      ),
    )
    hex_top_edges.push(
      hhwf_line_edge(
        ctx,
        hex_cp[i],
        hex_vp[i],
        hex_cp[j],
        hex_vp[j],
        hex_top_pos[i],
        hex_top_pos[j],
      ),
    )
  }

  let ring_center = xform.apply((0.0, 0.0, g.zb))
  let top_center = xform.apply((0.0, 0.0, g.k))
  let top_pos : Array[Vec3] = []
  for i in 0..<6 {
    let a = 60.0 * i.to_double() * @math.PI / 180.0
    top_pos.push(xform.apply((g.rt * @math.cos(a), g.rt * @math.sin(a), g.k)))
  }
  let top_cp = top_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let top_vp = top_cp.map(fn(c) { ctx.vertex_point(c) })
  let ring_arcs : Array[@step.Ref] = []
  let top_arcs : Array[@step.Ref] = []
  let seams : Array[@step.Ref] = []
  for i in 0..<6 {
    let j = (i + 1) % 6
    ring_arcs.push(
      hhwf_circle_edge(
        ctx,
        ring_center,
        g.rb,
        hex_cp[i],
        hex_vp[i],
        hex_cp[j],
        hex_vp[j],
        true,
        dir_up,
        dir_right,
      ),
    )
    top_arcs.push(
      hhwf_circle_edge(
        ctx,
        top_center,
        g.rt,
        top_cp[i],
        top_vp[i],
        top_cp[j],
        top_vp[j],
        true,
        dir_up,
        dir_right,
      ),
    )
    seams.push(
      hhwf_line_edge(
        ctx,
        hex_cp[i],
        hex_vp[i],
        top_cp[i],
        top_vp[i],
        hex_top_pos[i],
        top_pos[i],
      ),
    )
  }

  let faces : Array[@step.Ref] = []
  // Six hex flats.
  for i in 0..<6 {
    let j = (i + 1) % 6
    let phi = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    let plane = hhwf_plane(
      ctx,
      base_pos[i],
      v_norm(xform.apply_dir((@math.cos(phi), @math.sin(phi), 0.0))),
      v_norm(xform.apply_dir((0.0, 0.0, 1.0))),
    )
    faces.push(
      hhwf_face(
        ctx,
        [
          (bottom_edges[i], true),
          (vertical_edges[j], true),
          (hex_top_edges[i], false),
          (vertical_edges[i], false),
        ],
        plane,
        v_norm(xform.apply_dir((@math.cos(phi), @math.sin(phi), 0.0))),
        [base_pos[i], base_pos[j], hex_top_pos[j], hex_top_pos[i]],
      ),
    )
  }
  // Bottom hex.
  let bottom_oriented : Array[(@step.Ref, Bool)] = []
  let bottom_points : Array[Vec3] = []
  for i in 0..<6 {
    bottom_oriented.push((bottom_edges[(5 - i) % 6], false))
    bottom_points.push(base_pos[(5 - i) % 6])
  }
  let bottom_plane = hhwf_plane(
    ctx,
    base_pos[0],
    v_norm(xform.apply_dir((0.0, 0.0, -1.0))),
    v_norm(xform.apply_dir((1.0, 0.0, 0.0))),
  )
  faces.push(hhwf_face(ctx, bottom_oriented, bottom_plane, down, bottom_points))
  // Overhang ring at the chamfer base: outer circle arcs, inner hex.
  let ring_oriented : Array[(@step.Ref, Bool)] = []
  let ring_points : Array[Vec3] = []
  for i in 0..<6 {
    ring_oriented.push((ring_arcs[(5 - i) % 6], false))
    ring_points.push(hex_top_pos[(5 - i) % 6])
  }
  let ring_loop = ctx.edge_loop(
    ring_oriented.map(fn(e) { ctx.oriented_edge(e.0, e.1) }),
  )
  let hex_hole = ctx.edge_loop(
    hex_top_edges.map(fn(e) { ctx.oriented_edge(e, true) }),
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      hex_cp[0],
      down,
      right,
      ring_loop,
      [hex_hole],
      reverse~,
    ),
  )
  // Six chamfer cone patches.
  let cone = hhwf_cone(
    ctx,
    top_center,
    v_norm(xform.apply_dir((0.0, 0.0, 1.0))),
    v_norm(xform.apply_dir((1.0, 0.0, 0.0))),
    g.rt,
    75.0,
  )
  for i in 0..<6 {
    let j = (i + 1) % 6
    let cone_loop = ctx.edge_loop([
      ctx.oriented_edge(ring_arcs[i], true),
      ctx.oriented_edge(seams[j], true),
      ctx.oriented_edge(top_arcs[i], false),
      ctx.oriented_edge(seams[i], false),
    ])
    faces.push(
      ctx.advanced_face([ctx.face_outer_bound(cone_loop, true)], cone, !reverse),
    )
  }
  // Circular top face, split into six arcs.
  let top_loop = ctx.edge_loop(
    top_arcs.map(fn(e) { ctx.oriented_edge(e, true) }),
  )
  faces.push(
    add_plane_face_from_loops(ctx, top_cp[0], up, right, top_loop, [], reverse~),
  )
  faces
}

///|
fn hhwf_proxy(h : HexHeadWasherFace) -> ChamferedPrism? {
  let g = match hhwf_geometry(h) {
    Some(g) => g
    None => return None
  }
  Some(
    ChamferedPrism::from_chamfer(
      Profile2D::polygon(
        6,
        h.across_flats_mm / @math.cos(@math.PI / 6.0),
        rotation=0.0,
      ),
      g.k,
      top_chamfer=g.rb - g.rt,
      chamfer_depth=g.c,
    ),
  )
}
