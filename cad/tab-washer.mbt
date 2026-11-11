///|
// Analytic DIN 93 tab washer: one outer cylindrical arc, two concave
// transition cylinders, one bore cylinder, two tab-side planes, a tab-end
// plane, and two planar caps. The tab outline is a line/arc loop; the STEP
// writer emits exactly the reference topology (9 faces, 21 edges, 14
// vertices).

///|
priv struct TWGeom {
  r : Double
  rb : Double
  ww : Double
  l : Double
  h : Double
  rf : Double
  c_up : Vec2
  c_lo : Vec2
  out_up : Vec2
  out_lo : Vec2
  tab_up : Vec2
  tab_lo : Vec2
  end_up : Vec2
  end_lo : Vec2
}

///|
fn tw_geom(w : TabWasher) -> TWGeom? {
  let r = w.outer_diameter_mm / 2.0
  let rb = w.bore_diameter_mm / 2.0
  let ww = w.tab_width_mm / 2.0
  let l = w.tab_length_mm
  let h = w.thickness_mm
  let rf = w.fillet_radius_mm
  if r <= 0.0 ||
    rb <= 0.0 ||
    rb >= r ||
    ww <= 0.0 ||
    l <= 0.0 ||
    h <= 0.0 ||
    rf <= 0.0 ||
    r <= ww {
    return None
  }
  let dx = r + rf
  let dy = ww + rf
  if dx * dx <= dy * dy {
    return None
  }
  let xroot = Double::sqrt(dx * dx - dy * dy)
  if xroot >= l {
    return None
  }
  let c_up = (-xroot, dy)
  let c_lo = (-xroot, -dy)
  let scale = r / dx
  let out_up = (c_up.0 * scale, c_up.1 * scale)
  let out_lo = (c_lo.0 * scale, c_lo.1 * scale)
  Some({
    r,
    rb,
    ww,
    l,
    h,
    rf,
    c_up,
    c_lo,
    out_up,
    out_lo,
    tab_up: (-xroot, ww),
    tab_lo: (-xroot, -ww),
    end_up: (-l, ww),
    end_lo: (-l, -ww),
  })
}

///|
fn tw_world(p : Vec2, z : Double, xform : Transform) -> Vec3 {
  xform.apply((p.0, p.1, z))
}

///|
fn tw_cp(ctx : StepContext, p : Vec3) -> @step.Ref {
  ctx.cartesian_point(p.0, p.1, p.2)
}

///|
fn tw_arc_edge(
  ctx : StepContext,
  center : Vec2,
  radius : Double,
  z : Double,
  _start_cp : @step.Ref,
  start_vp : @step.Ref,
  _end_cp : @step.Ref,
  end_vp : @step.Ref,
  same_sense : Bool,
  xform : Transform,
  dir_up : @step.Ref,
  dir_right : @step.Ref,
) -> @step.Ref {
  let c = tw_world(center, z, xform)
  let ccp = tw_cp(ctx, c)
  let a2p = ctx.axis2_placement_3d(ccp, dir_up, dir_right)
  let circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", a2p, @step.fmt_num(radius)),
    ),
  )
  ctx.edge_curve(start_vp, end_vp, circle, same_sense)
}

///|
fn tw_line_edge(
  ctx : StepContext,
  a_cp : @step.Ref,
  a_vp : @step.Ref,
  _b_cp : @step.Ref,
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
fn tw_cylinder(
  ctx : StepContext,
  center : Vec2,
  radius : Double,
  xform : Transform,
  dir_up : @step.Ref,
  dir_right : @step.Ref,
) -> @step.Ref {
  let c = tw_world(center, 0.0, xform)
  let ccp = tw_cp(ctx, c)
  let a2p = ctx.axis2_placement_3d(ccp, dir_up, dir_right)
  ctx.add(
    @repository.any_entity_cylindrical_surface(
      @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(radius)),
    ),
  )
}

///|
fn tw_plane(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
) -> @step.Ref {
  let origin_cp = tw_cp(ctx, origin)
  let axis_ref = ctx.direction(axis.0, axis.1, axis.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let a2p = ctx.axis2_placement_3d(origin_cp, axis_ref, ref_ref)
  ctx.add(@repository.any_entity_plane(@geometry.Plane::new("", a2p)))
}

///|
fn tw_newell(points : Array[Vec3]) -> Vec3 {
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
fn tw_face(
  ctx : StepContext,
  edges : Array[(@step.Ref, Bool)],
  surface : @step.Ref,
  natural : Vec3,
  loop_points : Array[Vec3],
) -> @step.Ref {
  let oriented = edges.map(fn(e) { ctx.oriented_edge(e.0, e.1) })
  let edge_loop = ctx.edge_loop(oriented)
  let bound = ctx.face_outer_bound(edge_loop, true)
  let loop_normal = tw_newell(loop_points)
  let same = v_dot(loop_normal, natural) >= 0.0
  ctx.advanced_face([bound], surface, same)
}

///|
/// compile_tab_washer emits one closed solid for a DIN 93 tab washer.
pub fn compile_tab_washer(
  ctx : StepContext,
  node : SceneNode,
  w : TabWasher,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let g = match tw_geom(w) {
    Some(g) => g
    None => return []
  }
  let xform = node_transform(node, parent)
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)

  let p_out_up_b = tw_world(g.out_up, 0.0, xform)
  let p_out_up_t = tw_world(g.out_up, g.h, xform)
  let p_out_lo_b = tw_world(g.out_lo, 0.0, xform)
  let p_out_lo_t = tw_world(g.out_lo, g.h, xform)
  let p_fil_up_b = tw_world(g.tab_up, 0.0, xform)
  let p_fil_up_t = tw_world(g.tab_up, g.h, xform)
  let p_fil_lo_b = tw_world(g.tab_lo, 0.0, xform)
  let p_fil_lo_t = tw_world(g.tab_lo, g.h, xform)
  let p_tab_up_b = tw_world(g.end_up, 0.0, xform)
  let p_tab_up_t = tw_world(g.end_up, g.h, xform)
  let p_tab_lo_b = tw_world(g.end_lo, 0.0, xform)
  let p_tab_lo_t = tw_world(g.end_lo, g.h, xform)
  let p_seam_b = tw_world((g.rb, 0.0), 0.0, xform)
  let p_seam_t = tw_world((g.rb, 0.0), g.h, xform)

  let cp_out_up_b = tw_cp(ctx, p_out_up_b)
  let cp_out_up_t = tw_cp(ctx, p_out_up_t)
  let cp_out_lo_b = tw_cp(ctx, p_out_lo_b)
  let cp_out_lo_t = tw_cp(ctx, p_out_lo_t)
  let cp_fil_up_b = tw_cp(ctx, p_fil_up_b)
  let cp_fil_up_t = tw_cp(ctx, p_fil_up_t)
  let cp_fil_lo_b = tw_cp(ctx, p_fil_lo_b)
  let cp_fil_lo_t = tw_cp(ctx, p_fil_lo_t)
  let cp_tab_up_b = tw_cp(ctx, p_tab_up_b)
  let cp_tab_up_t = tw_cp(ctx, p_tab_up_t)
  let cp_tab_lo_b = tw_cp(ctx, p_tab_lo_b)
  let cp_tab_lo_t = tw_cp(ctx, p_tab_lo_t)
  let cp_seam_b = tw_cp(ctx, p_seam_b)
  let cp_seam_t = tw_cp(ctx, p_seam_t)

  let vp_out_up_b = ctx.vertex_point(cp_out_up_b)
  let vp_out_up_t = ctx.vertex_point(cp_out_up_t)
  let vp_out_lo_b = ctx.vertex_point(cp_out_lo_b)
  let vp_out_lo_t = ctx.vertex_point(cp_out_lo_t)
  let vp_fil_up_b = ctx.vertex_point(cp_fil_up_b)
  let vp_fil_up_t = ctx.vertex_point(cp_fil_up_t)
  let vp_fil_lo_b = ctx.vertex_point(cp_fil_lo_b)
  let vp_fil_lo_t = ctx.vertex_point(cp_fil_lo_t)
  let vp_tab_up_b = ctx.vertex_point(cp_tab_up_b)
  let vp_tab_up_t = ctx.vertex_point(cp_tab_up_t)
  let vp_tab_lo_b = ctx.vertex_point(cp_tab_lo_b)
  let vp_tab_lo_t = ctx.vertex_point(cp_tab_lo_t)
  let vp_seam_b = ctx.vertex_point(cp_seam_b)
  let vp_seam_t = ctx.vertex_point(cp_seam_t)

  // Bottom and top outline arcs and lines.
  let out_b = tw_arc_edge(
    ctx,
    (0.0, 0.0),
    g.r,
    0.0,
    cp_out_lo_b,
    vp_out_lo_b,
    cp_out_up_b,
    vp_out_up_b,
    true,
    xform,
    dir_up,
    dir_right,
  )
  let out_t = tw_arc_edge(
    ctx,
    (0.0, 0.0),
    g.r,
    g.h,
    cp_out_lo_t,
    vp_out_lo_t,
    cp_out_up_t,
    vp_out_up_t,
    true,
    xform,
    dir_up,
    dir_right,
  )
  let fil_up_b = tw_arc_edge(
    ctx,
    g.c_up,
    g.rf,
    0.0,
    cp_out_up_b,
    vp_out_up_b,
    cp_fil_up_b,
    vp_fil_up_b,
    false,
    xform,
    dir_up,
    dir_right,
  )
  let fil_up_t = tw_arc_edge(
    ctx,
    g.c_up,
    g.rf,
    g.h,
    cp_out_up_t,
    vp_out_up_t,
    cp_fil_up_t,
    vp_fil_up_t,
    false,
    xform,
    dir_up,
    dir_right,
  )
  let fil_lo_b = tw_arc_edge(
    ctx,
    g.c_lo,
    g.rf,
    0.0,
    cp_fil_lo_b,
    vp_fil_lo_b,
    cp_out_lo_b,
    vp_out_lo_b,
    false,
    xform,
    dir_up,
    dir_right,
  )
  let fil_lo_t = tw_arc_edge(
    ctx,
    g.c_lo,
    g.rf,
    g.h,
    cp_fil_lo_t,
    vp_fil_lo_t,
    cp_out_lo_t,
    vp_out_lo_t,
    false,
    xform,
    dir_up,
    dir_right,
  )
  let tab_up_b = tw_line_edge(
    ctx, cp_fil_up_b, vp_fil_up_b, cp_tab_up_b, vp_tab_up_b, p_fil_up_b, p_tab_up_b,
  )
  let tab_up_t = tw_line_edge(
    ctx, cp_fil_up_t, vp_fil_up_t, cp_tab_up_t, vp_tab_up_t, p_fil_up_t, p_tab_up_t,
  )
  let tab_lo_b = tw_line_edge(
    ctx, cp_tab_lo_b, vp_tab_lo_b, cp_fil_lo_b, vp_fil_lo_b, p_tab_lo_b, p_fil_lo_b,
  )
  let tab_lo_t = tw_line_edge(
    ctx, cp_tab_lo_t, vp_tab_lo_t, cp_fil_lo_t, vp_fil_lo_t, p_tab_lo_t, p_fil_lo_t,
  )
  let end_b = tw_line_edge(
    ctx, cp_tab_up_b, vp_tab_up_b, cp_tab_lo_b, vp_tab_lo_b, p_tab_up_b, p_tab_lo_b,
  )
  let end_t = tw_line_edge(
    ctx, cp_tab_up_t, vp_tab_up_t, cp_tab_lo_t, vp_tab_lo_t, p_tab_up_t, p_tab_lo_t,
  )
  let bore_b = tw_arc_edge(
    ctx,
    (0.0, 0.0),
    g.rb,
    0.0,
    cp_seam_b,
    vp_seam_b,
    cp_seam_b,
    vp_seam_b,
    true,
    xform,
    dir_up,
    dir_right,
  )
  let bore_t = tw_arc_edge(
    ctx,
    (0.0, 0.0),
    g.rb,
    g.h,
    cp_seam_t,
    vp_seam_t,
    cp_seam_t,
    vp_seam_t,
    true,
    xform,
    dir_up,
    dir_right,
  )
  let seam = tw_line_edge(
    ctx, cp_seam_b, vp_seam_b, cp_seam_t, vp_seam_t, p_seam_b, p_seam_t,
  )

  // Vertical edges.
  let vert = fn(
    a_cp : @step.Ref,
    a_vp : @step.Ref,
    b_cp : @step.Ref,
    b_vp : @step.Ref,
    a : Vec3,
    b : Vec3,
  ) -> @step.Ref {
    tw_line_edge(ctx, a_cp, a_vp, b_cp, b_vp, a, b)
  }
  let v_out_up = vert(
    cp_out_up_b, vp_out_up_b, cp_out_up_t, vp_out_up_t, p_out_up_b, p_out_up_t,
  )
  let v_out_lo = vert(
    cp_out_lo_b, vp_out_lo_b, cp_out_lo_t, vp_out_lo_t, p_out_lo_b, p_out_lo_t,
  )
  let v_fil_up = vert(
    cp_fil_up_b, vp_fil_up_b, cp_fil_up_t, vp_fil_up_t, p_fil_up_b, p_fil_up_t,
  )
  let v_fil_lo = vert(
    cp_fil_lo_b, vp_fil_lo_b, cp_fil_lo_t, vp_fil_lo_t, p_fil_lo_b, p_fil_lo_t,
  )
  let v_tab_up = vert(
    cp_tab_up_b, vp_tab_up_b, cp_tab_up_t, vp_tab_up_t, p_tab_up_b, p_tab_up_t,
  )
  let v_tab_lo = vert(
    cp_tab_lo_b, vp_tab_lo_b, cp_tab_lo_t, vp_tab_lo_t, p_tab_lo_b, p_tab_lo_t,
  )

  let faces : Array[@step.Ref] = []
  let outer_cyl = tw_cylinder(ctx, (0.0, 0.0), g.r, xform, dir_up, dir_right)
  let fil_up_cyl = tw_cylinder(ctx, g.c_up, g.rf, xform, dir_up, dir_right)
  let fil_lo_cyl = tw_cylinder(ctx, g.c_lo, g.rf, xform, dir_up, dir_right)
  let bore_cyl = tw_cylinder(ctx, (0.0, 0.0), g.rb, xform, dir_up, dir_right)

  // Cylinder faces. The natural normal is radial from each axis.
  let mid_out = v_norm(
    xform.apply_dir(
      (
        @math.cos(
          (
            @math.atan2(g.out_lo.1, g.out_lo.0) +
            @math.atan2(g.out_up.1, g.out_up.0)
          ) /
          2.0,
        ),
        @math.sin(
          (
            @math.atan2(g.out_lo.1, g.out_lo.0) +
            @math.atan2(g.out_up.1, g.out_up.0)
          ) /
          2.0,
        ),
        0.0,
      ),
    ),
  )
  faces.push(
    tw_face(
      ctx,
      [(out_b, true), (v_out_up, true), (out_t, false), (v_out_lo, false)],
      outer_cyl,
      mid_out,
      [p_out_lo_b, p_out_up_b, p_out_up_t, p_out_lo_t],
    ),
  )
  let fil_up_natural = v_norm(
    xform.apply_dir(
      (
        @math.cos(@math.atan2(g.out_up.1 - g.c_up.1, g.out_up.0 - g.c_up.0)),
        @math.sin(@math.atan2(g.out_up.1 - g.c_up.1, g.out_up.0 - g.c_up.0)),
        0.0,
      ),
    ),
  )
  faces.push(
    tw_face(
      ctx,
      [(fil_up_b, true), (v_fil_up, true), (fil_up_t, false), (v_out_up, false)],
      fil_up_cyl,
      fil_up_natural,
      [p_out_up_b, p_fil_up_b, p_fil_up_t, p_out_up_t],
    ),
  )
  let fil_lo_natural = v_norm(
    xform.apply_dir(
      (
        @math.cos(@math.atan2(g.out_lo.1 - g.c_lo.1, g.out_lo.0 - g.c_lo.0)),
        @math.sin(@math.atan2(g.out_lo.1 - g.c_lo.1, g.out_lo.0 - g.c_lo.0)),
        0.0,
      ),
    ),
  )
  faces.push(
    tw_face(
      ctx,
      [(fil_lo_b, true), (v_out_lo, true), (fil_lo_t, false), (v_fil_lo, false)],
      fil_lo_cyl,
      fil_lo_natural,
      [p_fil_lo_b, p_out_lo_b, p_out_lo_t, p_fil_lo_t],
    ),
  )
  let bore_loop = ctx.edge_loop([
    ctx.oriented_edge(seam, true),
    ctx.oriented_edge(bore_t, true),
    ctx.oriented_edge(seam, false),
    ctx.oriented_edge(bore_b, false),
  ])
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(bore_loop, true)],
      bore_cyl,
      reverse,
    ),
  )

  // Planar tab sides and end.
  let up_plane = tw_plane(
    ctx,
    p_fil_up_b,
    v_norm(xform.apply_dir((0.0, 1.0, 0.0))),
    v_norm(xform.apply_dir((0.0, 0.0, 1.0))),
  )
  faces.push(
    tw_face(
      ctx,
      [(tab_up_b, true), (v_tab_up, true), (tab_up_t, false), (v_fil_up, false)],
      up_plane,
      v_norm(xform.apply_dir((0.0, 1.0, 0.0))),
      [p_fil_up_b, p_tab_up_b, p_tab_up_t, p_fil_up_t],
    ),
  )
  let lo_plane = tw_plane(
    ctx,
    p_tab_lo_b,
    v_norm(xform.apply_dir((0.0, -1.0, 0.0))),
    v_norm(xform.apply_dir((0.0, 0.0, 1.0))),
  )
  faces.push(
    tw_face(
      ctx,
      [(tab_lo_b, true), (v_fil_lo, true), (tab_lo_t, false), (v_tab_lo, false)],
      lo_plane,
      v_norm(xform.apply_dir((0.0, -1.0, 0.0))),
      [p_tab_lo_b, p_fil_lo_b, p_fil_lo_t, p_tab_lo_t],
    ),
  )
  let end_plane = tw_plane(
    ctx,
    p_tab_up_b,
    v_norm(xform.apply_dir((-1.0, 0.0, 0.0))),
    v_norm(xform.apply_dir((0.0, 0.0, 1.0))),
  )
  faces.push(
    tw_face(
      ctx,
      [(end_b, true), (v_tab_lo, true), (end_t, false), (v_tab_up, false)],
      end_plane,
      v_norm(xform.apply_dir((-1.0, 0.0, 0.0))),
      [p_tab_up_b, p_tab_lo_b, p_tab_lo_t, p_tab_up_t],
    ),
  )

  // Caps: top uses the CCW outline; bottom reverses it.
  let cap_top_outer = ctx.edge_loop([
    ctx.oriented_edge(out_t, true),
    ctx.oriented_edge(fil_up_t, true),
    ctx.oriented_edge(tab_up_t, true),
    ctx.oriented_edge(end_t, true),
    ctx.oriented_edge(tab_lo_t, true),
    ctx.oriented_edge(fil_lo_t, true),
  ])
  let cap_bottom_outer = ctx.edge_loop([
    ctx.oriented_edge(fil_lo_b, false),
    ctx.oriented_edge(tab_lo_b, false),
    ctx.oriented_edge(end_b, false),
    ctx.oriented_edge(tab_up_b, false),
    ctx.oriented_edge(fil_up_b, false),
    ctx.oriented_edge(out_b, false),
  ])
  let cap_top_hole = ctx.edge_loop([ctx.oriented_edge(bore_t, false)])
  let cap_bottom_hole = ctx.edge_loop([ctx.oriented_edge(bore_b, true)])
  let top_origin = tw_world((0.0, 0.0), g.h, xform)
  let bottom_origin = tw_world((0.0, 0.0), 0.0, xform)
  let cap_reverse = reverse
  faces.push(
    add_plane_face_from_loops(
      ctx,
      tw_cp(ctx, bottom_origin),
      down,
      right,
      cap_bottom_outer,
      [cap_bottom_hole],
      reverse=cap_reverse,
    ),
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      tw_cp(ctx, top_origin),
      up,
      right,
      cap_top_outer,
      [cap_top_hole],
      reverse=cap_reverse,
    ),
  )
  faces
}

///|
fn tw_outline(w : TabWasher, arc_samples~ : Int32 = 96) -> Array[Vec2] {
  let g = match tw_geom(w) {
    Some(g) => g
    None => return []
  }
  let n = if arc_samples < 8 { 8 } else { arc_samples }
  let pts : Array[Vec2] = []
  // Outer major arc, lower-left tangent through +X to upper-left tangent.
  let a_lo = @math.atan2(g.out_lo.1, g.out_lo.0)
  let a_up = @math.atan2(g.out_up.1, g.out_up.0)
  for i in 0..<=n {
    let t = i.to_double() / n.to_double()
    let a = a_lo + (a_up - a_lo) * t
    pts.push((g.r * @math.cos(a), g.r * @math.sin(a)))
  }
  let fil_up_a0 = @math.atan2(g.out_up.1 - g.c_up.1, g.out_up.0 - g.c_up.0)
  let fil_up_a1 = @math.atan2(g.tab_up.1 - g.c_up.1, g.tab_up.0 - g.c_up.0)
  let add_fillet = fn(c : Vec2, a0 : Double, a1 : Double) -> Unit {
    for i in 1..<=n {
      let t = i.to_double() / n.to_double()
      let a = a0 + (a1 - a0) * t
      pts.push((c.0 + g.rf * @math.cos(a), c.1 + g.rf * @math.sin(a)))
    }
  }
  add_fillet(g.c_up, fil_up_a0, fil_up_a1)
  pts.push(g.end_up)
  pts.push(g.end_lo)
  let fil_lo_a0 = @math.atan2(g.tab_lo.1 - g.c_lo.1, g.tab_lo.0 - g.c_lo.0)
  let fil_lo_a1 = @math.atan2(g.out_lo.1 - g.c_lo.1, g.out_lo.0 - g.c_lo.0)
  add_fillet(g.c_lo, fil_lo_a0, fil_lo_a1)
  // The final point is the lower outer tangent; drop it if it duplicates the
  // first outline point.
  let nn = pts.length()
  if nn > 1 {
    let a = pts[nn - 1]
    let b = pts[0]
    if (a.0 - b.0).abs() < 1.0e-12 && (a.1 - b.1).abs() < 1.0e-12 {
      let _ = pts.pop()
    }
  }
  pts
}

///|
fn tw_polygon_moments(points : Array[Vec2]) -> (Double, Double, Double) {
  let n = points.length()
  let mut a = 0.0
  let mut mx = 0.0
  let mut my = 0.0
  for i in 0..<n {
    let p = points[i]
    let q = points[(i + 1) % n]
    let cross = p.0 * q.1 - q.0 * p.1
    a = a + cross
    mx = mx + (p.0 + q.0) * cross
    my = my + (p.1 + q.1) * cross
  }
  (a / 2.0, mx / 6.0, my / 6.0)
}

///|
fn tw_area_centroid(w : TabWasher) -> (Double, Vec2) {
  let g = match tw_geom(w) {
    Some(g) => g
    None => return (0.0, (0.0, 0.0))
  }
  let points = tw_outline(w)
  let (area, mx, my) = tw_polygon_moments(points)
  let bore = @math.PI * g.rb * g.rb
  let material = area - bore
  if material <= 0.0 {
    (0.0, (0.0, 0.0))
  } else {
    (material, (mx / area, my / area))
  }
}

///|
fn an_tab_inventory(w : TabWasher) -> SurfaceInventory {
  match tw_geom(w) {
    None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
    Some(_) => an_inventory(5, 4, 0, 0, 0, 0, 0, 0)
  }
}

///|
fn an_tab_section(w : TabWasher, z : Double) -> Result[Section, AnalysisError] {
  if z < -CAD_LENGTH_EPS || z > w.thickness_mm + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let g = match tw_geom(w) {
    Some(g) => g
    None => return Err(DegenerateProfile)
  }
  let (material, _c) = tw_area_centroid(w)
  if material <= 0.0 {
    return Err(EmptySection)
  }
  let points = tw_outline(w)
  let mut perimeter = 2.0 * @math.PI * g.rb
  for i in 0..<points.length() {
    let p = points[i]
    let q = points[(i + 1) % points.length()]
    perimeter = perimeter +
      Double::sqrt((p.0 - q.0) * (p.0 - q.0) + (p.1 - q.1) * (p.1 - q.1))
  }
  let outer = Double::sqrt(g.l * g.l + g.ww * g.ww)
  Ok({
    z_mm: z,
    area_mm2: material,
    perimeter_mm: perimeter,
    outer_radius_mm: outer,
    inner_radius_mm: g.rb,
    rings: [{ inner_radius_mm: g.rb, outer_radius_mm: outer, }],
  })
}

///|
fn tab_washer_mesh(
  w : TabWasher,
  arc_samples~ : Int32 = 96,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let g = match tw_geom(w) {
    Some(g) => g
    None => return ([], [])
  }
  let outline = tw_outline(w, arc_samples~)
  let n = outline.length()
  if n < 3 {
    return ([], [])
  }
  let verts : Array[Vec3] = []
  for p in outline {
    verts.push((p.0, p.1, 0.0))
  }
  for p in outline {
    verts.push(
      (
        g.rb * p.0 / Double::sqrt(p.0 * p.0 + p.1 * p.1),
        g.rb * p.1 / Double::sqrt(p.0 * p.0 + p.1 * p.1),
        0.0,
      ),
    )
  }
  for p in outline {
    verts.push((p.0, p.1, g.h))
  }
  for p in outline {
    verts.push(
      (
        g.rb * p.0 / Double::sqrt(p.0 * p.0 + p.1 * p.1),
        g.rb * p.1 / Double::sqrt(p.0 * p.0 + p.1 * p.1),
        g.h,
      ),
    )
  }
  let base_ob = 0
  let base_ib = n
  let base_ot = 2 * n
  let base_it = 3 * n
  let faces : Array[Array[Int32]] = []
  for i in 0..<n {
    let j = (i + 1) % n
    faces.push([base_ob + i, base_ob + j, base_ot + j, base_ot + i])
    faces.push([base_ib + i, base_ib + j, base_it + j, base_it + i])
    faces.push([base_ob + i, base_ib + i, base_ib + j, base_ob + j])
    faces.push([base_ot + i, base_ot + j, base_it + j, base_it + i])
  }
  (verts, faces)
}
