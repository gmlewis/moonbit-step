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
