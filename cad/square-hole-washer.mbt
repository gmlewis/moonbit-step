///|
// Analytic square-hole washer: one cylindrical outer face, two planar end
// faces with a square hole, and four planar square-hole walls. This is the
// topology of the DIN 440 V large washers (7 faces, 15 edges, 10 vertices).

///|
fn shw_line_edge(
  ctx : StepContext,
  a_cp : @step.Ref,
  a_vp : @step.Ref,
  _b_cp : @step.Ref,
  b_vp : @step.Ref,
  a_pos : Vec3,
  b_pos : Vec3,
) -> @step.Ref {
  let direction = v_norm(v_sub(b_pos, a_pos))
  let dir_ref = ctx.direction(direction.0, direction.1, direction.2)
  let vector_ref = ctx.vector(dir_ref, 1.0)
  let line_ref = ctx.line(a_cp, vector_ref)
  ctx.edge_curve(a_vp, b_vp, line_ref, true)
}

///|
fn shw_plane(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
) -> @step.Ref {
  let origin_cp = ctx.cartesian_point(origin.0, origin.1, origin.2)
  let axis_ref = ctx.direction(axis.0, axis.1, axis.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let placement = ctx.axis2_placement_3d(origin_cp, axis_ref, ref_ref)
  ctx.add(@repository.any_entity_plane(@geometry.Plane::new("", placement)))
}

///|
/// compile_square_hole_washer emits one closed solid for a centered square-hole
/// washer.
pub fn compile_square_hole_washer(
  ctx : StepContext,
  node : SceneNode,
  w : SquareHoleWasher,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let r = w.outer_diameter_mm / 2.0
  let a = w.square_side_mm
  let h = w.thickness_mm
  if r <= 0.0 || a <= 0.0 || h <= 0.0 || a * 0.5 * 1.4142135623730951 >= r {
    return []
  }
  let xform = node_transform(node, parent)
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)

  // Outer cylinder and its seam.
  let center_b = xform.apply((0.0, 0.0, 0.0))
  let center_t = xform.apply((0.0, 0.0, h))
  let cp_b = ctx.cartesian_point(center_b.0, center_b.1, center_b.2)
  let cp_t = ctx.cartesian_point(center_t.0, center_t.1, center_t.2)
  let a2p_b = ctx.axis2_placement_3d(cp_b, dir_up, dir_right)
  let a2p_t = ctx.axis2_placement_3d(cp_t, dir_up, dir_right)
  let radius_text = @step.fmt_num(r)
  let cylinder = ctx.add(
    @repository.any_entity_cylindrical_surface(
      @geometry.CylindricalSurface::new("", a2p_b, radius_text),
    ),
  )
  let circle_b = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_b, radius_text)),
  )
  let circle_t = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_t, radius_text)),
  )
  let seam_b = xform.apply((r, 0.0, 0.0))
  let seam_t = xform.apply((r, 0.0, h))
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
  let edge_cb = ctx.edge_curve(vp_sb, vp_sb, circle_b, true)
  let edge_ct = ctx.edge_curve(vp_st, vp_st, circle_t, true)
  let outer_loop = ctx.edge_loop([
    ctx.oriented_edge(seam, true),
    ctx.oriented_edge(edge_ct, false),
    ctx.oriented_edge(seam, false),
    ctx.oriented_edge(edge_cb, true),
  ])
  let faces : Array[@step.Ref] = []
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(outer_loop, true)],
      cylinder,
      !reverse,
    ),
  )

  // Square hole vertices: bottom 0..3, top 4..7.
  let half = a / 2.0
  let corners : Array[Vec2] = [
    (half, half),
    (-half, half),
    (-half, -half),
    (half, -half),
  ]
  let pts : Array[Vec3] = []
  for z in [0.0, h] {
    for p in corners {
      pts.push(xform.apply((p.0, p.1, z)))
    }
  }
  let cp_refs = pts.map(fn(p) { ctx.cartesian_point(p.0, p.1, p.2) })
  let vp_refs = cp_refs.map(fn(cp) { ctx.vertex_point(cp) })
  let bottom_edges : Array[@step.Ref] = []
  let top_edges : Array[@step.Ref] = []
  let vertical_edges : Array[@step.Ref] = []
  for i in 0..<4 {
    let j = (i + 1) % 4
    bottom_edges.push(
      shw_line_edge(
        ctx,
        cp_refs[i],
        vp_refs[i],
        cp_refs[j],
        vp_refs[j],
        pts[i],
        pts[j],
      ),
    )
    top_edges.push(
      shw_line_edge(
        ctx,
        cp_refs[4 + i],
        vp_refs[4 + i],
        cp_refs[4 + j],
        vp_refs[4 + j],
        pts[4 + i],
        pts[4 + j],
      ),
    )
    vertical_edges.push(
      shw_line_edge(
        ctx,
        cp_refs[i],
        vp_refs[i],
        cp_refs[4 + i],
        vp_refs[4 + i],
        pts[i],
        pts[4 + i],
      ),
    )
  }

  // Square-hole walls, outward normals pointing into the hole.
  for i in 0..<4 {
    let j = (i + 1) % 4
    let p0 = pts[i]
    let p1 = pts[j]
    let p2 = pts[4 + i]
    let edge_dir = v_sub(p1, p0)
    let expected = v_norm(v_cross(edge_dir, v_sub(p2, p0)))
    let wall_plane = shw_plane(
      ctx,
      p0,
      v_scale(expected, -1.0),
      v_norm(v_sub(p2, p0)),
    )
    let wall_loop = ctx.edge_loop([
      ctx.oriented_edge(vertical_edges[i], true),
      ctx.oriented_edge(top_edges[i], true),
      ctx.oriented_edge(vertical_edges[j], false),
      ctx.oriented_edge(bottom_edges[i], false),
    ])
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(wall_loop, true)],
        wall_plane,
        !reverse,
      ),
    )
  }

  // End caps: outer circle plus the square hole loop.
  let bottom_hole = ctx.edge_loop([
    ctx.oriented_edge(bottom_edges[0], true),
    ctx.oriented_edge(bottom_edges[1], true),
    ctx.oriented_edge(bottom_edges[2], true),
    ctx.oriented_edge(bottom_edges[3], true),
  ])
  let top_hole = ctx.edge_loop([
    ctx.oriented_edge(top_edges[3], false),
    ctx.oriented_edge(top_edges[2], false),
    ctx.oriented_edge(top_edges[1], false),
    ctx.oriented_edge(top_edges[0], false),
  ])
  let bottom_outer = ctx.edge_loop([ctx.oriented_edge(edge_cb, false)])
  let top_outer = ctx.edge_loop([ctx.oriented_edge(edge_ct, true)])
  faces.push(
    add_plane_face_from_loops(
      ctx,
      cp_b,
      down,
      right,
      bottom_outer,
      [bottom_hole],
      reverse~,
    ),
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      cp_t,
      up,
      right,
      top_outer,
      [top_hole],
      reverse~,
    ),
  )
  faces
}

///|
fn shw_area(w : SquareHoleWasher) -> Double {
  let r = w.outer_diameter_mm / 2.0
  @math.PI * r * r - w.square_side_mm * w.square_side_mm
}

///|
fn an_square_hole_inventory(w : SquareHoleWasher) -> SurfaceInventory {
  if shw_area(w) <= CAD_DEGENERATE_EPS || w.thickness_mm <= 0.0 {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  an_inventory(6, 1, 0, 0, 0, 0, 0, 0)
}

///|
fn an_square_hole_section(
  w : SquareHoleWasher,
  z : Double,
) -> Result[Section, AnalysisError] {
  if z < -CAD_LENGTH_EPS || z > w.thickness_mm + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let r = w.outer_diameter_mm / 2.0
  let a = w.square_side_mm
  let area = shw_area(w)
  if area <= CAD_DEGENERATE_EPS {
    return Err(EmptySection)
  }
  let inner = a / 2.0
  Ok({
    z_mm: z,
    area_mm2: area,
    perimeter_mm: 2.0 * @math.PI * r + 4.0 * a,
    outer_radius_mm: r,
    inner_radius_mm: inner,
    rings: [{ inner_radius_mm: inner, outer_radius_mm: r, }],
  })
}

///|
fn square_hole_mesh(
  w : SquareHoleWasher,
  segments~ : Int32 = 96,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let n = if segments < 16 { 16 } else { segments }
  let r = w.outer_diameter_mm / 2.0
  let half = w.square_side_mm / 2.0
  let h = w.thickness_mm
  let outer_b : Array[Vec3] = []
  let outer_t : Array[Vec3] = []
  let inner_b : Array[Vec3] = []
  let inner_t : Array[Vec3] = []
  for i in 0..<n {
    let th = 2.0 * @math.PI * Double::from_int(i) / Double::from_int(n)
    let cx = @math.cos(th)
    let sy = @math.sin(th)
    let max_abs = if cx.abs() > sy.abs() { cx.abs() } else { sy.abs() }
    let scale = half / max_abs
    outer_b.push((r * cx, r * sy, 0.0))
    outer_t.push((r * cx, r * sy, h))
    inner_b.push((scale * cx, scale * sy, 0.0))
    inner_t.push((scale * cx, scale * sy, h))
  }
  let verts : Array[Vec3] = []
  for p in outer_b {
    verts.push(p)
  }
  for p in inner_b {
    verts.push(p)
  }
  for p in outer_t {
    verts.push(p)
  }
  for p in inner_t {
    verts.push(p)
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
