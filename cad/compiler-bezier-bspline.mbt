///|
// Exact B-spline B-Rep for curved `ExtrudedBezierProfile` contours.
//
// The polyline path in `compiler_bezier.mbt` flattens every cubic span. That is
// fine for straight-sided glyphs but loses curved geometry. This file emits an
// exact representation instead: one closed cubic B-spline curve per contour,
// two planar caps bounded by that curve, and one lateral face on a
// `SURFACE_OF_LINEAR_EXTRUSION` with a single vertical seam edge.
//
// Topology follows the analytic cylinder convention:
//   bottom edge: lateral (forward) + bottom cap (reversed)
//   top edge:    lateral (reversed) + top cap (forward)
//   seam edge:   lateral only, used twice with opposite sense
// so every edge is used exactly twice with opposite orientation.

///|
/// BezierContourBoundary holds the STEP entities shared by the three faces of
/// one extruded contour.
priv struct BezierContourBoundary {
  bottom_edge : @step.Ref
  top_edge : @step.Ref
  seam_edge : @step.Ref
  bottom_start : @step.Ref
  top_start : @step.Ref
  start_dir : Vec3
  surface : @step.Ref
  up_dir : Vec3
}

///|
/// is_straight_span reports whether a cubic span actually traces a line.
fn is_straight_span(a0 : BezierAnchor, a1 : BezierAnchor) -> Bool {
  a0.handle_out == a0.position && a1.handle_in == a1.position
}

///|
/// path_has_curved_span reports whether any span (including the wrap-around
/// span of a closed contour) has non-degenerate Bezier handles.
fn path_has_curved_span(path : BezierPath) -> Bool {
  let anchors = path.anchors
  let n = anchors.length()
  if n < 2 {
    return false
  }
  for i in 0..<n {
    let a0 = anchors[i]
    let a1 = anchors[(i + 1) % n]
    if !is_straight_span(a0, a1) {
      return true
    }
  }
  false
}

///|
/// reverse_bezier_path reverses the traversal order of a contour while keeping
/// its geometry. Handles are absolute positions, so each anchor's incoming and
/// outgoing handles swap.
fn reverse_bezier_path(path : BezierPath) -> BezierPath {
  let anchors = path.anchors
  let n = anchors.length()
  let rev : Array[BezierAnchor] = []
  for i in 0..<n {
    let a = anchors[n - 1 - i]
    rev.push({
      position: a.position,
      handle_in: a.handle_out,
      handle_out: a.handle_in,
    })
  }
  { ..path, anchors: rev, }
}

///|
/// normalize_bezier_contour forces the contour winding. Outers must be
/// counter-clockwise and holes clockwise so that the cap loops and the lateral
/// surface normals agree, exactly like `compile_extruded_profile`.
fn normalize_bezier_contour(path : BezierPath, ccw~ : Bool) -> BezierPath {
  let poly = flatten_bezier_path(path)
  if poly.length() < 3 {
    return path
  }
  let area = polygon_area_2d(poly)
  if area == 0.0 {
    return path
  }
  let want_positive = ccw
  if (area > 0.0) != want_positive {
    reverse_bezier_path(path)
  } else {
    path
  }
}

///|
/// bspline_control_points converts a closed contour of cubic Bezier spans into
/// one clamped cubic B-spline control polygon.
///
/// Span `i` contributes `P0, C1, C2, P3`; the shared endpoint is emitted once.
/// Straight spans use collinear control points at one third and two thirds of
/// the way to the endpoint, which is an exact straight line (the task permits
/// this in place of degree-1 segments). Zero-length straight spans are dropped.
fn bspline_control_points(path : BezierPath) -> Array[Vec2] {
  let anchors = path.anchors
  let n = anchors.length()
  let cps : Array[Vec2] = []
  if n < 2 {
    return cps
  }
  let mut spans = 0
  for i in 0..<n {
    let a0 = anchors[i]
    let a1 = anchors[(i + 1) % n]
    let p0 = a0.position
    let p3 = a1.position
    let dx = p3.0 - p0.0
    let dy = p3.1 - p0.1
    let straight = is_straight_span(a0, a1)
    if straight && dx * dx + dy * dy <= 1.0e-18 {
      continue
    }
    let (c1, c2) = if straight {
      (
        (p0.0 + dx / 3.0, p0.1 + dy / 3.0),
        (p0.0 + 2.0 * dx / 3.0, p0.1 + 2.0 * dy / 3.0),
      )
    } else {
      (a0.handle_out, a1.handle_in)
    }
    if spans == 0 {
      cps.push(p0)
    }
    cps.push(c1)
    cps.push(c2)
    cps.push(p3)
    spans = spans + 1
  }
  cps
}

///|
/// BezierCurveBuild is the result of emitting one planar B-spline profile
/// curve: the curve ref, its control-point refs, and the transformed direction
/// of its first tangent (used as a stable plane reference direction).
priv struct BezierCurveBuild {
  curve : @step.Ref
  points : Array[@step.Ref]
  start_dir : Vec3
}

///|
/// add_bspline_curve emits one clamped cubic `B_SPLINE_CURVE_WITH_KNOTS` at
/// height `z`. Interior knot multiplicity 3 reduces continuity to C0 at span
/// joins, matching concatenated cubic Beziers.
fn add_bspline_curve(
  ctx : StepContext,
  cps : Array[Vec2],
  z : Double,
  xform : Transform,
) -> BezierCurveBuild {
  let points = cps.map(fn(p) {
    let w = xform.apply((p.0, p.1, z))
    ctx.cartesian_point(w.0, w.1, w.2)
  })
  let span_count = (cps.length() - 1) / 3
  let mults : Array[Int32] = [4]
  for _ in 1..<span_count {
    mults.push(3)
  }
  mults.push(4)
  let knots : Array[String] = []
  for i in 0..<=span_count {
    knots.push(@step.fmt_num(i.to_double()))
  }
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", 3, points, ".UNSPECIFIED.", true, false, mults, knots, ".UNSPECIFIED.",
  )
  let curve_ref = ctx.add(
    @repository.any_entity_b_spline_curve_with_knots(curve),
  )
  let s0 = xform.apply((cps[0].0, cps[0].1, z))
  let s1 = xform.apply((cps[1].0, cps[1].1, z))
  let start_dir = v_norm(v_sub(s1, s0))
  { curve: curve_ref, points, start_dir, }
}

///|
/// compile_bezier_contour emits the boundary entities for one contour.
fn compile_bezier_contour(
  ctx : StepContext,
  path : BezierPath,
  height : Double,
  xform : Transform,
) -> BezierContourBoundary? {
  let cps = bspline_control_points(path)
  if cps.length() < 4 {
    return None
  }
  let bottom = add_bspline_curve(ctx, cps, 0.0, xform)
  let top = add_bspline_curve(ctx, cps, height, xform)
  let vb = ctx.vertex_point(bottom.points[0])
  let vt = ctx.vertex_point(top.points[0])
  let bottom_edge = ctx.edge_curve(vb, vb, bottom.curve, true)
  let top_edge = ctx.edge_curve(vt, vt, top.curve, true)
  let up_dir = xform.apply_dir((0.0, 0.0, 1.0))
  let up_ref = ctx.direction(up_dir.0, up_dir.1, up_dir.2)
  let seam_line = ctx.line(bottom.points[0], ctx.vector(up_ref, 1.0))
  let seam_edge = ctx.edge_curve(vb, vt, seam_line, true)
  let surface = @geometry.SurfaceOfLinearExtrusion::new(
    "",
    bottom.curve,
    ctx.vector(up_ref, height),
  )
  let surface_ref = ctx.add(
    @repository.any_entity_surface_of_linear_extrusion(surface),
  )
  Some({
    bottom_edge,
    top_edge,
    seam_edge,
    bottom_start: bottom.points[0],
    top_start: top.points[0],
    start_dir: bottom.start_dir,
    surface: surface_ref,
    up_dir,
  })
}

///|
/// add_cap_from_boundaries emits one planar cap bounded by the profile curves.
/// The bottom cap uses the reversed loops (outward normal -Z), the top cap the
/// forward loops (outward normal +Z).
fn add_cap_from_boundaries(
  ctx : StepContext,
  outer : BezierContourBoundary,
  holes : Array[BezierContourBoundary],
  bottom~ : Bool,
  reverse~ : Bool,
) -> @step.Ref {
  let (axis_raw, location) = if bottom {
    ((-outer.up_dir.0, -outer.up_dir.1, -outer.up_dir.2), outer.bottom_start)
  } else {
    (outer.up_dir, outer.top_start)
  }
  let axis_ref = ctx.direction(axis_raw.0, axis_raw.1, axis_raw.2)
  let ref_ref = ctx.direction(
    outer.start_dir.0,
    outer.start_dir.1,
    outer.start_dir.2,
  )
  let a2p_ref = ctx.axis2_placement_3d(location, axis_ref, ref_ref)
  let plane = @geometry.Plane::new("", a2p_ref)
  let plane_ref = ctx.add(@repository.any_entity_plane(plane))

  let outer_loop_refs = loop_edges(ctx, outer, bottom~, forward=!bottom)
  let outer_loop = ctx.edge_loop(outer_loop_refs)
  let fob_ref = ctx.face_outer_bound(outer_loop, true)
  let bounds : Array[@step.Ref] = [fob_ref]
  for hole in holes {
    let hole_loop_refs = loop_edges(ctx, hole, bottom~, forward=!bottom)
    let hole_loop = ctx.edge_loop(hole_loop_refs)
    bounds.push(ctx.face_bound(hole_loop, true))
  }
  ctx.advanced_face(bounds, plane_ref, !reverse)
}

///|
/// loop_edges returns the oriented edge list for a closed contour boundary.
fn loop_edges(
  ctx : StepContext,
  b : BezierContourBoundary,
  bottom~ : Bool,
  forward~ : Bool,
) -> Array[@step.Ref] {
  let edge = if bottom { b.bottom_edge } else { b.top_edge }
  if forward {
    [ctx.oriented_edge(edge, true)]
  } else {
    [ctx.oriented_edge(edge, false)]
  }
}

///|
/// add_lateral_from_boundary emits the `SURFACE_OF_LINEAR_EXTRUSION` band.
fn add_lateral_from_boundary(
  ctx : StepContext,
  b : BezierContourBoundary,
  reverse~ : Bool,
) -> @step.Ref {
  let edge_loop_ref = ctx.edge_loop([
    ctx.oriented_edge(b.bottom_edge, true),
    ctx.oriented_edge(b.seam_edge, true),
    ctx.oriented_edge(b.top_edge, false),
    ctx.oriented_edge(b.seam_edge, false),
  ])
  let fob_ref = ctx.face_outer_bound(edge_loop_ref, true)
  ctx.advanced_face([fob_ref], b.surface, !reverse)
}

///|
/// compile_curved_bezier_group emits one closed contour triplet per path.
fn compile_curved_bezier_group(
  ctx : StepContext,
  node : SceneNode,
  group : Array[BezierPath],
  height : Double,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  if group.is_empty() {
    return []
  }
  let xform = node_transform(node, parent)
  let outer_path = normalize_bezier_contour(group[0], ccw=true)
  let outer = match compile_bezier_contour(ctx, outer_path, height, xform) {
    Some(b) => b
    None => return []
  }
  let holes : Array[BezierContourBoundary] = []
  for i in 1..<group.length() {
    let hole_path = normalize_bezier_contour(group[i], ccw=false)
    match compile_bezier_contour(ctx, hole_path, height, xform) {
      Some(b) => holes.push(b)
      None => ()
    }
  }
  let faces : Array[@step.Ref] = []
  faces.push(add_cap_from_boundaries(ctx, outer, holes, bottom=true, reverse~))
  faces.push(add_cap_from_boundaries(ctx, outer, holes, bottom=false, reverse~))
  faces.push(add_lateral_from_boundary(ctx, outer, reverse~))
  for hole in holes {
    faces.push(add_lateral_from_boundary(ctx, hole, reverse~))
  }
  faces
}
