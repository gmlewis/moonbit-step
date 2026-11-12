///|
// Exact conical-washer-face hex head with SURFACE_CURVE edges and pcurves.
//
// Topology: six planar hex flats bounded above by two hyperbolas each, six
// triangular cone patches (two hyperbolas + a top circle arc), a circular top
// face split into six arcs, and the hex underside. The pcurves are degree-1
// parameter-space polylines, so importers can relate every edge to both of its
// faces without guessing.

///|
priv struct HHPlaneRef {
  surface : @step.Ref
  origin : Vec3
  axis : Vec3
  reference : Vec3
}

///|
priv struct HHConeRef {
  surface : @step.Ref
  origin : Vec3
  axis : Vec3
  reference : Vec3
  radius : Double
  semi_angle_deg : Double
}

///|
fn hhp_plane(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
) -> HHPlaneRef {
  let surface = hhwf_plane(ctx, origin, axis, reference)
  { surface, origin, axis: v_norm(axis), reference: v_norm(reference), }
}

///|
fn hhp_cone(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
  radius : Double,
  semi_angle_deg : Double,
) -> HHConeRef {
  let surface = hhwf_cone(ctx, origin, axis, reference, radius, semi_angle_deg)
  {
    surface,
    origin,
    axis: v_norm(axis),
    reference: v_norm(reference),
    radius,
    semi_angle_deg,
  }
}

///|
fn hhp_plane_uv(p : Vec3, plane : HHPlaneRef) -> (Double, Double) {
  let xdir = plane.reference
  let ydir = v_norm(v_cross(plane.axis, plane.reference))
  let d = v_sub(p, plane.origin)
  (v_dot(d, xdir), v_dot(d, ydir))
}

///|
fn hhp_cone_uv(p : Vec3, cone : HHConeRef) -> (Double, Double) {
  let xdir = cone.reference
  let ydir = v_norm(v_cross(cone.axis, cone.reference))
  let d = v_sub(p, cone.origin)
  let u = @math.atan2(v_dot(d, ydir), v_dot(d, xdir))
  let v = v_dot(d, cone.axis)
  (u, v)
}

///|
fn hhp_pcurve_polyline(
  ctx : StepContext,
  surface : @step.Ref,
  uv : Array[(Double, Double)],
  context_2d : @step.Ref,
) -> @step.Ref {
  let n = uv.length()
  if n < 2 {
    return ctx.pcurve(surface, ctx.definitional_representation([], context_2d))
  }
  let cps : Array[@step.Ref] = []
  let mut previous_u = 0.0
  for i, (u, v) in uv {
    let mut uu = u
    if i > 0 {
      while uu - previous_u > @math.PI {
        uu = uu - 2.0 * @math.PI
      }
      while uu - previous_u < -@math.PI {
        uu = uu + 2.0 * @math.PI
      }
    }
    previous_u = uu
    cps.push(ctx.cartesian_point_2d(uu, v))
  }
  let mults : Array[Int32] = [2]
  for _ in 1..<(n - 1) {
    mults.push(1)
  }
  mults.push(2)
  let knots : Array[String] = []
  for i in 0..<n {
    knots.push(@step.fmt_num(i.to_double()))
  }
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", 1, cps, ".UNSPECIFIED.", false, false, mults, knots, ".PIECEWISE_BEZIER_KNOTS.",
  )
  let curve_ref = ctx.add(
    @repository.any_entity_b_spline_curve_with_knots(curve),
  )
  let rep = ctx.definitional_representation([curve_ref], context_2d)
  ctx.pcurve(surface, rep)
}

///|
fn hhp_surface_edge(
  ctx : StepContext,
  curve_3d : @step.Ref,
  samples : Array[Vec3],
  plane_a : HHPlaneRef,
  plane_b : HHPlaneRef?,
  cone_b : HHConeRef?,
  context_2d : @step.Ref,
  start_vp : @step.Ref,
  end_vp : @step.Ref,
  reverse_curve~ : Bool = false,
) -> @step.Ref {
  let uv_a = samples.map(fn(p) { hhp_plane_uv(p, plane_a) })
  let pc_a = hhp_pcurve_polyline(ctx, plane_a.surface, uv_a, context_2d)
  let assoc : Array[@step.Ref] = [pc_a]
  match plane_b {
    Some(pb) => {
      let uv_b = samples.map(fn(p) { hhp_plane_uv(p, pb) })
      assoc.push(hhp_pcurve_polyline(ctx, pb.surface, uv_b, context_2d))
    }
    None =>
      match cone_b {
        Some(cb) => {
          let uv_b = samples.map(fn(p) { hhp_cone_uv(p, cb) })
          assoc.push(hhp_pcurve_polyline(ctx, cb.surface, uv_b, context_2d))
        }
        None => ()
      }
  }
  let sc = ctx.surface_curve(curve_3d, assoc)
  ctx.edge_curve(start_vp, end_vp, sc, !reverse_curve)
}

///|
fn hhp_hyperbola_samples(
  phi : Double,
  rt : Double,
  tan_alpha : Double,
  zb : Double,
  k : Double,
  from_base : Bool,
  xform : Transform,
) -> Array[Vec3] {
  let tangent = (-@math.sin(phi), @math.cos(phi), 0.0)
  let n = 48
  let pts : Array[Vec3] = []
  for i in 0..<=n {
    let t = i.to_double() / n.to_double()
    let z = if from_base { zb + (k - zb) * t } else { k - (k - zb) * t }
    let w = k - z
    let u = Double::sqrt(
      2.0 * rt * tan_alpha * w + tan_alpha * tan_alpha * w * w,
    )
    let sign = if from_base { 1.0 } else { -1.0 }
    let local = (
      rt * @math.cos(phi) + sign * u * tangent.0,
      rt * @math.sin(phi) + sign * u * tangent.1,
      z,
    )
    pts.push(xform.apply(local))
  }
  pts
}

///|
fn hhp_polyline3d(ctx : StepContext, samples : Array[Vec3]) -> @step.Ref {
  let cps = samples.map(fn(p) { hhwf_cp(ctx, p) })
  let poly = @geometry.Polyline::new("", cps)
  ctx.add(@repository.any_entity_polyline(poly))
}

///|
/// compile_hex_head_pcurves emits the exact conical-washer-face head.
pub fn compile_hex_head_pcurves(
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
  let context_2d = ctx.context_2d()

  // Vertices.
  let base_pos : Array[Vec3] = []
  let mid_pos : Array[Vec3] = []
  let top_pos : Array[Vec3] = []
  for i in 0..<6 {
    let a = 60.0 * i.to_double() * @math.PI / 180.0
    let b = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    base_pos.push(xform.apply((g.rb * @math.cos(a), g.rb * @math.sin(a), 0.0)))
    mid_pos.push(xform.apply((g.rb * @math.cos(a), g.rb * @math.sin(a), g.zb)))
    top_pos.push(xform.apply((g.rt * @math.cos(b), g.rt * @math.sin(b), g.k)))
  }
  let base_cp = base_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let mid_cp = mid_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let top_cp = top_pos.map(fn(p) { hhwf_cp(ctx, p) })
  let base_vp = base_cp.map(fn(c) { ctx.vertex_point(c) })
  let mid_vp = mid_cp.map(fn(c) { ctx.vertex_point(c) })
  let top_vp = top_cp.map(fn(c) { ctx.vertex_point(c) })

  // Surfaces.
  let underside = hhp_plane(ctx, xform.apply((0.0, 0.0, 0.0)), down, right)
  let top_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, g.k)), up, right)
  let flat_planes : Array[HHPlaneRef] = []
  for i in 0..<6 {
    let phi = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    let normal = v_norm(xform.apply_dir((@math.cos(phi), @math.sin(phi), 0.0)))
    let midpoint = xform.apply(
      (g.rt * @math.cos(phi), g.rt * @math.sin(phi), 0.0),
    )
    flat_planes.push(
      hhp_plane(ctx, midpoint, normal, v_norm(xform.apply_dir((0.0, 0.0, 1.0)))),
    )
  }
  let cone = hhp_cone(
    ctx,
    xform.apply((0.0, 0.0, g.zb)),
    v_norm(xform.apply_dir((0.0, 0.0, -1.0))),
    v_norm(xform.apply_dir((1.0, 0.0, 0.0))),
    g.rb,
    75.0,
  )

  // Bottom hex edges.
  let bottom_edges : Array[@step.Ref] = []
  for i in 0..<6 {
    let j = (i + 1) % 6
    let curve = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          base_cp[i],
          ctx.direction(
            v_norm(v_sub(base_pos[j], base_pos[i])).0,
            v_norm(v_sub(base_pos[j], base_pos[i])).1,
            v_norm(v_sub(base_pos[j], base_pos[i])).2,
          )
          |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    bottom_edges.push(
      hhp_surface_edge(
        ctx,
        curve,
        [base_pos[i], base_pos[j]],
        underside,
        Some(flat_planes[i]),
        None,
        context_2d,
        base_vp[i],
        base_vp[j],
      ),
    )
  }
  // Vertical hex edges at each vertex.
  let vertical_edges : Array[@step.Ref] = []
  for i in 0..<6 {
    let dir = v_norm(v_sub(mid_pos[i], base_pos[i]))
    let curve = ctx.add(
      @repository.any_entity_line(
        @geometry.Line::new(
          "",
          base_cp[i],
          ctx.direction(dir.0, dir.1, dir.2) |> d => { ctx.vector(d, 1.0) },
        ),
      ),
    )
    vertical_edges.push(
      hhp_surface_edge(
        ctx,
        curve,
        [base_pos[i], mid_pos[i]],
        flat_planes[(i + 5) % 6],
        Some(flat_planes[i]),
        None,
        context_2d,
        base_vp[i],
        mid_vp[i],
      ),
    )
  }
  // Hyperbola edges: left and right of each flat.
  let hyper_left : Array[@step.Ref] = []
  let hyper_right : Array[@step.Ref] = []
  for i in 0..<6 {
    let phi = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    let center = xform.apply(
      (g.rt * @math.cos(phi), g.rt * @math.sin(phi), g.k + g.rt / g.tan_alpha),
    )
    let axis = v_norm(xform.apply_dir((-@math.cos(phi), -@math.sin(phi), 0.0)))
    let reference = v_norm(xform.apply_dir((0.0, 0.0, -1.0)))
    let a2p = ctx.axis2_placement_3d(
      hhwf_cp(ctx, center),
      ctx.direction(axis.0, axis.1, axis.2),
      ctx.direction(reference.0, reference.1, reference.2),
    )
    let hyperbola = ctx.add(
      @repository.any_entity_hyperbola(
        @geometry.Hyperbola::new("", a2p, g.rt / g.tan_alpha, g.rt),
      ),
    )
    let samples_base = hhp_hyperbola_samples(
      phi,
      g.rt,
      g.tan_alpha,
      g.zb,
      g.k,
      true,
      xform,
    )
    let curve_left = hyperbola
    // Left half: base vertex i -> top midpoint i.
    hyper_left.push(
      hhp_surface_edge(
        ctx,
        curve_left,
        samples_base.rev(),
        flat_planes[i],
        None,
        Some(cone),
        context_2d,
        top_vp[i],
        mid_vp[i],
      ),
    )
    // Right half: top midpoint i -> base vertex i+1.
    let samples_rev = samples_base.rev()
    let curve_right = hyperbola
    hyper_right.push(
      hhp_surface_edge(
        ctx,
        curve_right,
        samples_base,
        flat_planes[i],
        None,
        Some(cone),
        context_2d,
        mid_vp[(i + 1) % 6],
        top_vp[i],
      ),
    )
  }
  // Top circle arcs.
  let top_edges : Array[@step.Ref] = []
  for i in 0..<6 {
    let j = (i + 1) % 6
    let a0 = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    let a1 = (30.0 + 60.0 * j.to_double()) * @math.PI / 180.0
    let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, g.k)))
    let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(g.rt)),
      ),
    )
    let samples : Array[Vec3] = []
    for s in 0..<=12 {
      let t = s.to_double() / 12.0
      let a = a0 + (a1 - a0) * t
      samples.push(xform.apply((g.rt * @math.cos(a), g.rt * @math.sin(a), g.k)))
    }
    top_edges.push(
      hhp_surface_edge(
        ctx,
        circle,
        samples,
        top_plane,
        None,
        Some(cone),
        context_2d,
        top_vp[i],
        top_vp[j],
      ),
    )
  }

  let faces : Array[@step.Ref] = []
  // Flat faces.
  for i in 0..<6 {
    let j = (i + 1) % 6
    faces.push(
      hhwf_face(
        ctx,
        [
          (bottom_edges[i], true),
          (vertical_edges[j], true),
          (hyper_right[i], true),
          (hyper_left[i], true),
          (vertical_edges[i], false),
        ],
        flat_planes[i].surface,
        flat_planes[i].axis,
        [base_pos[i], base_pos[j], mid_pos[j], top_pos[i], mid_pos[i]],
      ),
    )
  }
  // Cone faces.
  for i in 0..<6 {
    let j = (i + 1) % 6
    let natural = v_norm(
      xform.apply_dir(
        (
          @math.cos(60.0 * i.to_double() * @math.PI / 180.0) *
          @math.cos(15.0 * @math.PI / 180.0),
          @math.sin(60.0 * i.to_double() * @math.PI / 180.0) *
          @math.cos(15.0 * @math.PI / 180.0),
          @math.sin(15.0 * @math.PI / 180.0),
        ),
      ),
    )
    faces.push(
      hhwf_face(
        ctx,
        [
          (hyper_left[i], false),
          (top_edges[(i + 5) % 6], false),
          (hyper_right[(i + 5) % 6], false),
        ],
        cone.surface,
        natural,
        [mid_pos[i], top_pos[(i + 5) % 6], top_pos[i]],
      ),
    )
  }
  // Underside hex (opposite the flats' bottom edges).
  let underside_plane = hhwf_plane(
    ctx,
    xform.apply((0.0, 0.0, 0.0)),
    v_norm(xform.apply_dir((0.0, 0.0, -1.0))),
    v_norm(xform.apply_dir((1.0, 0.0, 0.0))),
  )
  let underside_oriented : Array[(@step.Ref, Bool)] = []
  let underside_points : Array[Vec3] = []
  for i in 0..<6 {
    underside_oriented.push((bottom_edges[(5 - i) % 6], false))
    underside_points.push(base_pos[(5 - i) % 6])
  }
  faces.push(
    hhwf_face(
      ctx,
      underside_oriented,
      underside_plane,
      v_norm(xform.apply_dir((0.0, 0.0, -1.0))),
      underside_points,
    ),
  )
  // Top circle (forward, opposite the cone faces' top arcs).
  let top_loop = ctx.edge_loop(
    top_edges.map(fn(e) { ctx.oriented_edge(e, true) }),
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      hhwf_cp(ctx, xform.apply((0.0, 0.0, g.k))),
      up,
      right,
      top_loop,
      [],
      reverse~,
    ),
  )
  faces
}
