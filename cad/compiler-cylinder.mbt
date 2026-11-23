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
  let band = compile_cylindrical_band(
    ctx,
    origin_b_ref,
    origin_t_ref,
    up_ref,
    right_ref,
    r,
    xform.apply((r, 0.0, 0.0)),
    xform.apply((r, 0.0, h)),
    down_ref=Some(down_ref),
    cap_planes=true,
  )

  // Bounds.
  let bottom_loop_ref = ctx.edge_loop([
    ctx.oriented_edge(band.bottom_edge, false),
  ])
  let top_loop_ref = ctx.edge_loop([ctx.oriented_edge(band.top_edge, true)])
  let lateral_bound_ref = ctx.face_outer_bound(band.lateral_loop, true)
  let bottom_bound_ref = ctx.face_outer_bound(bottom_loop_ref, true)
  let top_bound_ref = ctx.face_outer_bound(top_loop_ref, true)
  [
    ctx.advanced_face([lateral_bound_ref], band.surface, !reverse),
    ctx.advanced_face([bottom_bound_ref], band.bottom_plane.unwrap(), !reverse),
    ctx.advanced_face([top_bound_ref], band.top_plane.unwrap(), !reverse),
  ]
}
