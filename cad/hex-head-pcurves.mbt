///|
// Exact conical-washer-face hex head with SURFACE_CURVE edges and pcurves.
//
// Topology: six planar hex flats bounded above by two hyperbolas each, six
// triangular chamfer patches (two hyperbolas + a top circle arc), a circular
// top face split into six arcs, and the hex underside. The chamfer is the
// golden's own representation: a 75 degree CONICAL_SURFACE per patch, trimmed
// by the flats. Every edge of a patch carries a pcurve on each of its two
// faces, so an importer can relate it to both surfaces without guessing.
//
// This imports with no face warnings and gives the exact reference volume
// (22.13797 mm3 for M2 against 22.1379 analytic, 475.479 mm3 for M5 x 20,
// matching the golden). The one prerequisite is that the global context
// declares the RADIAN plane-angle unit: `cad/context.mbt` used to declare
// DEGREE while the writer emitted radian-valued semi-angles, which made
// importers that honour the context read 75 as 75 degrees, rebuild every cone
// as a near cylinder and drop the chamfer faces.

///|
/// HHSArc is one circle level split into two half-arcs (u = 0 -> pi and
/// pi -> 2pi) with the vertices at +X and -X. Bands and annuli share these
/// edges, so no face needs a seam.
priv struct HHSArc {
  v0 : @step.Ref
  v1 : @step.Ref
  a : @step.Ref
  b : @step.Ref
}

///|
priv struct HHPlaneRef {
  surface : @step.Ref
  origin : Vec3
  axis : Vec3
  reference : Vec3
}

///|
/// HHConeRef is one chamfer's conical surface. The 75 degree washer-face cone
/// is trimmed by the six flats, so each of the six patches is a part of this
/// cone; the u-window per patch is small because each patch has its own
/// surface entity, referenced at the patch's leading top point.
priv struct HHConeRef {
  surface : @step.Ref
  origin : Vec3
  axis : Vec3
  reference : Vec3
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
/// hhp_cone creates the chamfer's CONICAL_SURFACE. `hhwf_cone` converts its
/// semi-angle to radians, which is what the global context's plane-angle unit
/// declares, so the emitted cone is read as 75 degrees by every importer.
fn hhp_cone(
  ctx : StepContext,
  origin : Vec3,
  axis : Vec3,
  reference : Vec3,
  radius : Double,
  semi_angle_deg : Double,
) -> HHConeRef {
  let surface = hhwf_cone(ctx, origin, axis, reference, radius, semi_angle_deg)
  { surface, origin, axis: v_norm(axis), reference: v_norm(reference), }
}

///|
/// hhp_cone_uv maps a point into the cone's parameter space (u = angle from the
/// patch's reference direction, v = distance along the cone's axis).
fn hhp_cone_uv(p : Vec3, cone : HHConeRef) -> (Double, Double) {
  let xdir = cone.reference
  let ydir = v_norm(v_cross(cone.axis, cone.reference))
  let d = v_sub(p, cone.origin)
  let u = @math.atan2(v_dot(d, ydir), v_dot(d, xdir))
  let v = v_dot(d, cone.axis)
  (u, v)
}

///|
fn hhp_plane_uv(p : Vec3, plane : HHPlaneRef) -> (Double, Double) {
  let xdir = plane.reference
  let ydir = v_norm(v_cross(plane.axis, plane.reference))
  let d = v_sub(p, plane.origin)
  (v_dot(d, xdir), v_dot(d, ydir))
}

///|

///|
fn hhp_pcurve_2d_line(
  ctx : StepContext,
  surface : @step.Ref,
  a : (Double, Double),
  b : (Double, Double),
  context_2d : @step.Ref,
) -> @step.Ref {
  let du = b.0 - a.0
  let dv = b.1 - a.1
  let len = Double::sqrt(du * du + dv * dv)
  let direction = if len == 0.0 { (1.0, 0.0) } else { (du / len, dv / len) }
  let pnt = ctx.cartesian_point_2d(a.0, a.1)
  let dir = ctx.add(
    @repository.any_entity_direction(
      @geometry.Direction::new("", [direction.0, direction.1]),
    ),
  )
  let vec = ctx.add(
    @repository.any_entity_vector(@geometry.Vector::new("", dir, 1.0)),
  )
  let line = ctx.add(
    @repository.any_entity_line(@geometry.Line::new("", pnt, vec)),
  )
  let rep = ctx.definitional_representation([line], context_2d)
  ctx.pcurve(surface, rep)
}

///|
/// hhp_pcurve_circle writes an exact 2D circle pcurve (the reference files'
/// representation for the top arcs on the top plane).
fn hhp_pcurve_circle(
  ctx : StepContext,
  surface : @step.Ref,
  center_u : Double,
  center_v : Double,
  radius : Double,
  context_2d : @step.Ref,
) -> @step.Ref {
  let location = ctx.cartesian_point_2d(center_u, center_v)
  let ref_dir = ctx.add(
    @repository.any_entity_direction(@geometry.Direction::new("", [1.0, 0.0])),
  )
  let placement = @geometry.Axis2Placement2D::new(
    "",
    location,
    ref_direction=Some(ref_dir),
  )
  let placement_ref = ctx.add(
    @repository.any_entity_axis2_placement_2d(placement),
  )
  let circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", placement_ref, @step.fmt_num(radius)),
    ),
  )
  let rep = ctx.definitional_representation([circle], context_2d)
  ctx.pcurve(surface, rep)
}

///|
/// hhp_pcurve_hyperbola writes the flat/cone intersection as a 2D hyperbola.
/// The flat plane's u axis is the tangential direction and its v axis points
/// down, so the transverse axis is +v: ref_direction (0, 1), semi-axis along v.
fn hhp_pcurve_hyperbola(
  ctx : StepContext,
  surface : @step.Ref,
  center_u : Double,
  center_v : Double,
  semi_axis : Double,
  semi_imag : Double,
  context_2d : @step.Ref,
) -> @step.Ref {
  let location = ctx.cartesian_point_2d(center_u, center_v)
  let ref_dir = ctx.add(
    @repository.any_entity_direction(@geometry.Direction::new("", [0.0, 1.0])),
  )
  let placement = @geometry.Axis2Placement2D::new(
    "",
    location,
    ref_direction=Some(ref_dir),
  )
  let placement_ref = ctx.add(
    @repository.any_entity_axis2_placement_2d(placement),
  )
  let hyperbola = ctx.add(
    @repository.any_entity_hyperbola(
      @geometry.Hyperbola::new("", placement_ref, semi_axis, semi_imag),
    ),
  )
  let rep = ctx.definitional_representation([hyperbola], context_2d)
  ctx.pcurve(surface, rep)
}

///|
fn hhp_all_collinear(uv : Array[(Double, Double)]) -> Bool {
  let n = uv.length()
  if n < 2 {
    return false
  }
  let du = uv[n - 1].0 - uv[0].0
  let dv = uv[n - 1].1 - uv[0].1
  let len = Double::sqrt(du * du + dv * dv)
  if len < 1.0e-12 {
    return false
  }
  for (u, v) in uv {
    let cross = (u - uv[0].0) * dv - (v - uv[0].1) * du
    if Double::abs(cross) / len > 1.0e-9 {
      return false
    }
  }
  true
}

///|
fn hhp_asinh(x : Double) -> Double {
  @math.ln(x + Double::sqrt(x * x + 1.0))
}

///|
fn hhp_pcurve_polyline(
  ctx : StepContext,
  surface : @step.Ref,
  uv : Array[(Double, Double)],
  context_2d : @step.Ref,
  params : Array[Double]?,
) -> @step.Ref {
  let n = uv.length()
  if n < 2 {
    return ctx.pcurve(surface, ctx.definitional_representation([], context_2d))
  }
  // A degree-1 LINE pcurve is only equivalent when the pcurve parameter is the
  // distance along it. With explicit parameters the knots must be those
  // parameters (the 3D curve's own parameter values), so keep the B-spline.
  if hhp_all_collinear(uv) && params is None {
    return hhp_pcurve_2d_line(ctx, surface, uv[0], uv[n - 1], context_2d)
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
  match params {
    Some(ps) =>
      if ps.length() == n {
        for p in ps {
          knots.push(@step.fmt_num(p))
        }
      } else {
        for i in 0..<n {
          knots.push(@step.fmt_num(i.to_double()))
        }
      }
    None =>
      for i in 0..<n {
        knots.push(@step.fmt_num(i.to_double()))
      }
  }
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", 1, cps, ".UNSPECIFIED.", false, false, mults, knots, ".UNSPECIFIED.",
  )
  let curve_ref = ctx.add(
    @repository.any_entity_b_spline_curve_with_knots(curve),
  )
  let rep = ctx.definitional_representation([curve_ref], context_2d)
  ctx.pcurve(surface, rep)
}

///|
/// hhp_surface_edge builds an EDGE_CURVE whose 3D curve carries a pcurve for
/// each adjacent surface. `samples`/`params` are in the edge's start -> end
/// order; `edge_forward` says whether that order agrees with the 3D curve's own
/// parameter direction. Pcurves always follow the 3D curve's parameterization,
/// so they are reversed when the edge runs against it.
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
  flat_hyperbola? : (Double, Double, Double, Double),
  plane_a_circle? : (Double, Double, Double),
  params? : Array[Double],
  edge_forward~ : Bool = true,
) -> @step.Ref {
  let pc_samples = if edge_forward { samples } else { samples.rev() }
  let pc_params = match params {
    Some(ps) => if edge_forward { Some(ps) } else { Some(ps.rev()) }
    None => None
  }
  let uv_a = pc_samples.map(fn(p) { hhp_plane_uv(p, plane_a) })
  let pc_a = match flat_hyperbola {
    Some((cu, cv, sa, sb)) =>
      hhp_pcurve_hyperbola(ctx, plane_a.surface, cu, cv, sa, sb, context_2d)
    None =>
      match plane_a_circle {
        Some((cu, cv, r)) =>
          hhp_pcurve_circle(ctx, plane_a.surface, cu, cv, r, context_2d)
        None =>
          hhp_pcurve_polyline(ctx, plane_a.surface, uv_a, context_2d, pc_params)
      }
  }
  let assoc : Array[@step.Ref] = [pc_a]
  match plane_b {
    Some(pb) => {
      let uv_b = pc_samples.map(fn(p) { hhp_plane_uv(p, pb) })
      assoc.push(
        hhp_pcurve_polyline(ctx, pb.surface, uv_b, context_2d, pc_params),
      )
    }
    None =>
      match cone_b {
        Some(cb) => {
          let uv_b = pc_samples.map(fn(p) { hhp_cone_uv(p, cb) })
          assoc.push(
            hhp_pcurve_polyline(ctx, cb.surface, uv_b, context_2d, pc_params),
          )
        }
        None => ()
      }
  }
  let sc = ctx.surface_curve(curve_3d, assoc)
  ctx.edge_curve(start_vp, end_vp, sc, edge_forward)
}

///|
/// hhp_hyperbola_samples samples one half of the flat/cone hyperbola. `side` is
/// +1 for the half towards the next base vertex and -1 for the half towards the
/// previous one; `from_base` selects the traversal direction.
fn hhp_hyperbola_samples(
  phi : Double,
  rt : Double,
  tan_alpha : Double,
  zb : Double,
  k : Double,
  side : Double,
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
    let p_local = (
      rt * @math.cos(phi) + side * u * tangent.0,
      rt * @math.sin(phi) + side * u * tangent.1,
      z,
    )
    pts.push(xform.apply(p_local))
  }
  pts
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
    base_pos.push(
      xform.apply((g.rb * @math.cos(a), g.rb * @math.sin(a), g.z_base)),
    )
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
  let underside = hhp_plane(ctx, xform.apply((0.0, 0.0, g.z_base)), down, right)
  let top_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, g.k)), up, right)
  let flat_planes : Array[HHPlaneRef] = []
  for i in 0..<6 {
    let phi = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    let normal = v_norm(xform.apply_dir((@math.cos(phi), @math.sin(phi), 0.0)))
    let midpoint = xform.apply(
      (g.rt * @math.cos(phi), g.rt * @math.sin(phi), 0.0),
    )
    // The plane's u axis runs backwards along the tangent (towards decreasing
    // azimuth) and its v axis points down (-Z). That frame makes the flat/cone
    // intersection a 2D hyperbola with a positive semi-axis, exactly as the
    // reference files write it.
    let ref_dir = v_norm(
      xform.apply_dir((@math.sin(phi), -@math.cos(phi), 0.0)),
    )
    flat_planes.push(hhp_plane(ctx, midpoint, normal, ref_dir))
  }
  // One conical surface per chamfer patch, referenced at the patch's leading
  // top point, so each patch's pcurves sit in a small, seam-free u-window.
  let cones : Array[HHConeRef] = []
  for i in 0..<6 {
    let lead = (60.0 * i.to_double() - 30.0) * @math.PI / 180.0
    cones.push(
      hhp_cone(
        ctx,
        xform.apply((0.0, 0.0, g.zb)),
        v_norm(xform.apply_dir((0.0, 0.0, -1.0))),
        v_norm(xform.apply_dir((@math.cos(lead), @math.sin(lead), 0.0))),
        g.rb,
        g.face_angle_deg,
      ),
    )
  }

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
    // Outward axis and a downward reference, as in the reference files: the
    // curve's Y axis then runs along +tangent, so the parameter grows from
    // the top tangency point towards either base vertex.
    let axis = v_norm(xform.apply_dir((@math.cos(phi), @math.sin(phi), 0.0)))
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
    // The flat plane's u axis is -tangent, so the hyperbola parameter is
    // asinh(-u / rt).
    let params_for = fn(samples : Array[Vec3]) -> Array[Double] {
      samples.map(fn(p) { hhp_asinh(-hhp_plane_uv(p, flat_planes[i]).0 / g.rt) })
    }
    // Left half: top tangency point i -> base vertex i.
    let left_samples = hhp_hyperbola_samples(
      phi,
      g.rt,
      g.tan_alpha,
      g.zb,
      g.k,
      -1.0,
      false,
      xform,
    )
    let left_params = params_for(left_samples)
    hyper_left.push(
      hhp_surface_edge(
        ctx,
        hyperbola,
        left_samples,
        flat_planes[i],
        None,
        Some(cones[i]),
        context_2d,
        top_vp[i],
        mid_vp[i],
        flat_hyperbola=(
          0.0,
          -(g.k + g.rt / g.tan_alpha),
          g.rt / g.tan_alpha,
          g.rt,
        ),
        params=left_params,
        edge_forward=false,
      ),
    )
    // Right half: base vertex i+1 -> top tangency point i.
    let right_samples = hhp_hyperbola_samples(
      phi,
      g.rt,
      g.tan_alpha,
      g.zb,
      g.k,
      1.0,
      true,
      xform,
    )
    let right_params = params_for(right_samples)
    hyper_right.push(
      hhp_surface_edge(
        ctx,
        hyperbola,
        right_samples,
        flat_planes[i],
        None,
        Some(cones[(i + 1) % 6]),
        context_2d,
        mid_vp[(i + 1) % 6],
        top_vp[i],
        flat_hyperbola=(
          0.0,
          -(g.k + g.rt / g.tan_alpha),
          g.rt / g.tan_alpha,
          g.rt,
        ),
        params=right_params,
        edge_forward=false,
      ),
    )
  }
  // Top circle arcs.
  let top_edges : Array[@step.Ref] = []
  for i in 0..<6 {
    let j = (i + 1) % 6
    let a0 = (30.0 + 60.0 * i.to_double()) * @math.PI / 180.0
    // Always sweep forwards by one sixth of a turn; computing the end angle
    // from the wrapped vertex index would run the last arc backwards and
    // produce decreasing pcurve knots.
    let a1 = a0 + @math.PI / 3.0
    let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, g.k)))
    let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(g.rt)),
      ),
    )
    let samples : Array[Vec3] = []
    let angles : Array[Double] = []
    for s in 0..<=12 {
      let t = s.to_double() / 12.0
      let a = a0 + (a1 - a0) * t
      samples.push(xform.apply((g.rt * @math.cos(a), g.rt * @math.sin(a), g.k)))
      angles.push(a)
    }
    top_edges.push(
      hhp_surface_edge(
        ctx,
        circle,
        samples,
        top_plane,
        None,
        Some(cones[(i + 1) % 6]),
        context_2d,
        top_vp[i],
        top_vp[j],
        plane_a_circle=(0.0, 0.0, g.rt),
        params=angles,
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
    // The reference cone faces use the same sense as their conical surface
    // and all three boundary edges reversed; do the same explicitly.
    let cone_loop = ctx.edge_loop([
      ctx.oriented_edge(hyper_left[i], false),
      ctx.oriented_edge(top_edges[(i + 5) % 6], false),
      ctx.oriented_edge(hyper_right[(i + 5) % 6], false),
    ])
    faces.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(cone_loop, true)],
        cones[i].surface,
        !reverse,
      ),
    )
  }
  // Underside. Head-only: the full hex underside (opposite the flats' bottom
  // edges), reusing the plane entity the bottom edges' pcurves reference.
  // With a shank: an annular underside (or under-head washer face), a land
  // cylinder, and the shank with its tip break, all in the same closed shell.
  let has_shank = h.shank_diameter_mm > 0.0 && h.shank_length_mm > 0.0
  let hex_oriented : Array[@step.Ref] = []
  for i in 0..<6 {
    hex_oriented.push(ctx.oriented_edge(bottom_edges[(5 - i) % 6], false))
  }
  if !has_shank {
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
        underside.surface,
        underside.axis,
        underside_points,
      ),
    )
  } else {
    let r_h = h.shank_diameter_mm / 2.0
    let r_w = h.washer_face_diameter_mm / 2.0
    let has_washer = r_w > 0.0 && h.washer_face_height_mm > 0.0
    let length = h.shank_length_mm
    let c_tip = if h.tip_chamfer_mm > 0.0 && h.tip_chamfer_mm < r_h {
      h.tip_chamfer_mm
    } else {
      0.0
    }
    let z_shank_bot = -length + c_tip
    let z_tip = -length
    let half_level = fn(z : Double, r : Double) -> HHSArc {
      let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, z)))
      let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
      let circle = ctx.add(
        @repository.any_entity_circle(
          @geometry.Circle::new("", a2p, @step.fmt_num(r)),
        ),
      )
      let cp0 = hhwf_cp(ctx, xform.apply((r, 0.0, z)))
      let cp1 = hhwf_cp(ctx, xform.apply((-r, 0.0, z)))
      let v0 = ctx.vertex_point(cp0)
      let v1 = ctx.vertex_point(cp1)
      {
        v0,
        v1,
        a: ctx.edge_curve(v0, v1, circle, true),
        b: ctx.edge_curve(v1, v0, circle, true),
      }
    }
    let cylinder_at = fn(z : Double, r : Double) -> @step.Ref {
      let center_cp = hhwf_cp(ctx, xform.apply((0.0, 0.0, z)))
      let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
      ctx.add(
        @repository.any_entity_cylindrical_surface(
          @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(r)),
        ),
      )
    }
    let band = fn(
      z0 : Double,
      r0 : Double,
      lo : HHSArc,
      z1 : Double,
      r1 : Double,
      hi : HHSArc,
      surface : @step.Ref,
    ) -> Unit {
      let dir0 = v_norm(
        v_sub(xform.apply((r1, 0.0, z1)), xform.apply((r0, 0.0, z0))),
      )
      let dir1 = v_norm(
        v_sub(xform.apply((-r1, 0.0, z1)), xform.apply((-r0, 0.0, z0))),
      )
      let seam0 = ctx.edge_curve(
        lo.v0,
        hi.v0,
        ctx.line(
          hhwf_cp(ctx, xform.apply((r0, 0.0, z0))),
          ctx.vector(ctx.direction(dir0.0, dir0.1, dir0.2), 1.0),
        ),
        true,
      )
      let seam1 = ctx.edge_curve(
        lo.v1,
        hi.v1,
        ctx.line(
          hhwf_cp(ctx, xform.apply((-r0, 0.0, z0))),
          ctx.vector(ctx.direction(dir1.0, dir1.1, dir1.2), 1.0),
        ),
        true,
      )
      let loop_a = ctx.edge_loop([
        ctx.oriented_edge(seam0, true),
        ctx.oriented_edge(hi.a, true),
        ctx.oriented_edge(seam1, false),
        ctx.oriented_edge(lo.a, false),
      ])
      let loop_b = ctx.edge_loop([
        ctx.oriented_edge(seam1, true),
        ctx.oriented_edge(hi.b, true),
        ctx.oriented_edge(seam0, false),
        ctx.oriented_edge(lo.b, false),
      ])
      faces.push(
        ctx.advanced_face(
          [ctx.face_outer_bound(loop_a, true)],
          surface,
          reverse,
        ),
      )
      faces.push(
        ctx.advanced_face(
          [ctx.face_outer_bound(loop_b, true)],
          surface,
          reverse,
        ),
      )
    }
    let hex_loop = ctx.edge_loop(hex_oriented)
    let tip_plane = hhp_plane(ctx, xform.apply((0.0, 0.0, z_tip)), down, right)
    let l_top = half_level(0.0, r_h)
    let l_bot = half_level(z_shank_bot, r_h)
    if has_washer {
      let under0 = hhp_plane(ctx, xform.apply((0.0, 0.0, 0.0)), down, right)
      let l_wtop = half_level(h.washer_face_height_mm, r_w)
      let l_wbot = half_level(0.0, r_w)
      faces.push(
        ctx.advanced_face(
          [
            ctx.face_outer_bound(hex_loop, true),
            ctx.face_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_wtop.a, false),
                ctx.oriented_edge(l_wtop.b, false),
              ]),
              true,
            ),
          ],
          underside.surface,
          !reverse,
        ),
      )
      band(
        0.0,
        r_w,
        l_wbot,
        h.washer_face_height_mm,
        r_w,
        l_wtop,
        cylinder_at(0.0, r_w),
      )
      faces.push(
        ctx.advanced_face(
          [
            ctx.face_outer_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_wbot.a, true),
                ctx.oriented_edge(l_wbot.b, true),
              ]),
              true,
            ),
            ctx.face_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_top.a, false),
                ctx.oriented_edge(l_top.b, false),
              ]),
              true,
            ),
          ],
          under0.surface,
          reverse,
        ),
      )
    } else {
      faces.push(
        ctx.advanced_face(
          [
            ctx.face_outer_bound(hex_loop, true),
            ctx.face_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_top.a, false),
                ctx.oriented_edge(l_top.b, false),
              ]),
              true,
            ),
          ],
          underside.surface,
          !reverse,
        ),
      )
    }
    band(
      z_shank_bot,
      r_h,
      l_bot,
      0.0,
      r_h,
      l_top,
      cylinder_at(z_shank_bot, r_h),
    )
    if c_tip > 0.0 {
      let tip_r = r_h - c_tip
      let l_tip = half_level(z_tip, tip_r)
      band(
        z_tip,
        tip_r,
        l_tip,
        z_shank_bot,
        r_h,
        l_bot,
        hhwf_cone(
          ctx,
          xform.apply((0.0, 0.0, z_shank_bot - r_h)),
          up,
          right,
          0.0,
          45.0,
        ),
      )
      faces.push(
        ctx.advanced_face(
          [
            ctx.face_outer_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_tip.a, true),
                ctx.oriented_edge(l_tip.b, true),
              ]),
              true,
            ),
          ],
          tip_plane.surface,
          reverse,
        ),
      )
    } else {
      faces.push(
        ctx.advanced_face(
          [
            ctx.face_outer_bound(
              ctx.edge_loop([
                ctx.oriented_edge(l_bot.a, true),
                ctx.oriented_edge(l_bot.b, true),
              ]),
              true,
            ),
          ],
          tip_plane.surface,
          reverse,
        ),
      )
    }
  }
  // Top circle (forward, opposite the cone faces' top arcs). As above, the
  // face reuses the top plane that the arcs' pcurves reference.
  let top_loop = ctx.edge_loop(
    top_edges.map(fn(e) { ctx.oriented_edge(e, true) }),
  )
  faces.push(
    ctx.advanced_face(
      [ctx.face_outer_bound(top_loop, true)],
      top_plane.surface,
      !reverse,
    ),
  )
  faces
}
