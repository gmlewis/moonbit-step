///|
/// compile_cylinder emits a solid right circular cylinder as three analytic
/// faces: one `CYLINDRICAL_SURFACE` band and two circular `PLANE` caps.
///
/// Topology: the lateral surface is cut along the seam at +X. The seam edge
/// runs from V0 = (r, 0, 0) to V1 = (r, 0, h); each cap edge is a closed
/// `EDGE_CURVE` that starts and ends at its own vertex. The lateral loop
/// traverses the seam up, the top circle backwards, the seam down, and the
/// bottom circle forwards, so every edge is used exactly twice with opposite
/// sense (the seam twice within the same face, which is the ISO 10303 seam
/// convention).
pub fn compile_cylinder(
  ctx : StepContext,
  node : SceneNode,
  cylinder : Cylinder,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let r = cylinder.diameter / 2.0
  let h = cylinder.height
  if r <= 0.0 || h <= 0.0 {
    return []
  }
  let xform = node_transform(node, parent)
  let radius = @step.fmt_num(r)

  // Surface frames, transformed with the node.
  let origin_b = xform.apply((0.0, 0.0, 0.0))
  let origin_t = xform.apply((0.0, 0.0, h))
  let origin_b_ref = ctx.cartesian_point(origin_b.0, origin_b.1, origin_b.2)
  let origin_t_ref = ctx.cartesian_point(origin_t.0, origin_t.1, origin_t.2)
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let up_ref = ctx.direction(up.0, up.1, up.2)
  let down_ref = ctx.direction(down.0, down.1, down.2)
  let right_ref = ctx.direction(right.0, right.1, right.2)

  // The lateral surface and both circular edges follow +Z. The bottom cap's
  // plane points outward (-Z) so its placement, not a flipped same_sense,
  // defines the face normal.
  let a2p_bottom = ctx.axis2_placement_3d(origin_b_ref, up_ref, right_ref)
  let a2p_top = ctx.axis2_placement_3d(origin_t_ref, up_ref, right_ref)
  let a2p_bottom_plane = ctx.axis2_placement_3d(
    origin_b_ref, down_ref, right_ref,
  )

  // Analytic geometry.
  let circle_bottom_ref = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_bottom, radius)),
  )
  let circle_top_ref = ctx.add(
    @repository.any_entity_circle(@geometry.Circle::new("", a2p_top, radius)),
  )
  let lateral_surface_ref = ctx.add(
    @repository.any_entity_cylindrical_surface(
      @geometry.CylindricalSurface::new("", a2p_bottom, radius),
    ),
  )
  let bottom_plane_ref = ctx.add(
    @repository.any_entity_plane(@geometry.Plane::new("", a2p_bottom_plane)),
  )
  let top_plane_ref = ctx.add(
    @repository.any_entity_plane(@geometry.Plane::new("", a2p_top)),
  )

  // Seam vertices and geometry.
  let v0 = xform.apply((r, 0.0, 0.0))
  let v1 = xform.apply((r, 0.0, h))
  let cp0 = ctx.cartesian_point(v0.0, v0.1, v0.2)
  let cp1 = ctx.cartesian_point(v1.0, v1.1, v1.2)
  let vp0 = ctx.vertex_point(cp0)
  let vp1 = ctx.vertex_point(cp1)
  let seam_line_ref = ctx.line(cp0, ctx.vector(up_ref, 1.0))

  // Edges.
  let seam_ref = ctx.edge_curve(vp0, vp1, seam_line_ref, true)
  let bottom_edge_ref = ctx.edge_curve(vp0, vp0, circle_bottom_ref, true)
  let top_edge_ref = ctx.edge_curve(vp1, vp1, circle_top_ref, true)

  // Bounds.
  let lateral_loop_ref = ctx.edge_loop([
    ctx.oriented_edge(seam_ref, true),
    ctx.oriented_edge(top_edge_ref, false),
    ctx.oriented_edge(seam_ref, false),
    ctx.oriented_edge(bottom_edge_ref, true),
  ])
  let bottom_loop_ref = ctx.edge_loop([
    ctx.oriented_edge(bottom_edge_ref, false),
  ])
  let top_loop_ref = ctx.edge_loop([ctx.oriented_edge(top_edge_ref, true)])
  let lateral_bound_ref = ctx.face_outer_bound(lateral_loop_ref, true)
  let bottom_bound_ref = ctx.face_outer_bound(bottom_loop_ref, true)
  let top_bound_ref = ctx.face_outer_bound(top_loop_ref, true)

  // Faces.
  [
    ctx.advanced_face([lateral_bound_ref], lateral_surface_ref, !reverse),
    ctx.advanced_face([bottom_bound_ref], bottom_plane_ref, !reverse),
    ctx.advanced_face([top_bound_ref], top_plane_ref, !reverse),
  ]
}
