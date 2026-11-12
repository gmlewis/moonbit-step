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
  face_angle_deg : Double
  z_base : Double
}

///|
fn hhwf_geometry(h : HexHeadWasherFace) -> HHWFGeometry? {
  let s = h.across_flats_mm
  let k = h.head_height_mm
  if s <= 0.0 || k <= 0.0 || h.face_angle_deg <= 0.0 {
    return None
  }
  let rb = s / Double::sqrt(3.0)
  let rt = s / 2.0
  let tan_alpha = @math.tan(h.face_angle_deg * @math.PI / 180.0)
  let c = (rb - rt) / tan_alpha
  let zb = k - c
  let z_base = if h.washer_face_diameter_mm > 0.0 {
    h.washer_face_height_mm
  } else {
    0.0
  }
  if zb <= z_base {
    return None
  }
  Some({
    rb,
    rt,
    k,
    zb,
    c,
    tan_alpha,
    face_angle_deg: h.face_angle_deg,
    z_base,
  })
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

///|
/// hhwf_sort_unique sorts axial breakpoints ascending and removes duplicates
/// without clamping negative values (unlike the radius-only helper).
fn hhwf_sort_unique(values : Array[Double], tol : Double) -> Array[Double] {
  let sorted = values.copy()
  let n = sorted.length()
  for i in 1..<n {
    let v = sorted[i]
    let mut j = i - 1
    while j >= 0 && sorted[j] > v {
      sorted[j + 1] = sorted[j]
      j = j - 1
    }
    sorted[j + 1] = v
  }
  let out : Array[Double] = []
  for v in sorted {
    let keep = match out.last() {
      Some(prev) => v - prev > tol
      None => true
    }
    if keep {
      out.push(v)
    }
  }
  out
}

///|
/// hhwf_screw_has_shank reports whether the head carries the unified shank.
fn hhwf_screw_has_shank(h : HexHeadWasherFace) -> Bool {
  h.shank_diameter_mm > 0.0 && h.shank_length_mm > 0.0
}

///|
/// hhwf_screw_area returns the exact cross-section area of the unified
/// shank + washer-face head at local `z`.
fn hhwf_screw_area(h : HexHeadWasherFace, z : Double) -> Double {
  let g = match hhwf_geometry(h) {
    Some(v) => v
    None => return 0.0
  }
  let r_h = h.shank_diameter_mm / 2.0
  let l = h.shank_length_mm
  let c = if h.tip_chamfer_mm > 0.0 && h.tip_chamfer_mm < r_h {
    h.tip_chamfer_mm
  } else {
    0.0
  }
  if z < -l - CAD_LENGTH_EPS || z > g.k + CAD_LENGTH_EPS {
    return 0.0
  }
  if z <= 0.0 {
    let z0 = -l + c
    let r = if z < z0 { r_h - (z0 - z) } else { r_h }
    if r <= 0.0 {
      return 0.0
    }
    return @math.PI * r * r
  }
  let has_w = h.washer_face_diameter_mm > 0.0 && h.washer_face_height_mm > 0.0
  if has_w && z < h.washer_face_height_mm {
    let rw = h.washer_face_diameter_mm / 2.0
    return @math.PI * rw * rw
  }
  if z <= g.zb {
    return h.across_flats_mm * h.across_flats_mm * Double::sqrt(3.0) / 2.0
  }
  let r = g.rt + (g.k - z) * g.tan_alpha
  if r <= g.rt {
    @math.PI * r * r
  } else if r >= g.rb {
    h.across_flats_mm * h.across_flats_mm * Double::sqrt(3.0) / 2.0
  } else {
    @math.PI * r * r - 6.0 * conut_circular_segment(r, g.rt, g.rb)
  }
}

///|
/// hhwf_screw_volume_centroid integrates the unified screw exactly by
/// composite Simpson over its kink-free spans.
fn hhwf_screw_volume_centroid(h : HexHeadWasherFace) -> (Double, Double) {
  let g = match hhwf_geometry(h) {
    Some(v) => v
    None => return (0.0, 0.0)
  }
  let r_h = h.shank_diameter_mm / 2.0
  let l = h.shank_length_mm
  let c = if h.tip_chamfer_mm > 0.0 && h.tip_chamfer_mm < r_h {
    h.tip_chamfer_mm
  } else {
    0.0
  }
  let zs : Array[Double] = [-l, -l + c, 0.0, g.zb, g.k]
  if h.washer_face_diameter_mm > 0.0 && h.washer_face_height_mm > 0.0 {
    zs.push(h.washer_face_height_mm)
  }
  let sorted = hhwf_sort_unique(zs, 1.0e-9)
  let mut volume = 0.0
  let mut moment = 0.0
  let samples = 64
  for i in 0..<(sorted.length() - 1) {
    let z0 = sorted[i]
    let z1 = sorted[i + 1]
    let hstep = (z1 - z0) / Double::from_int(samples)
    if hstep <= CAD_DEGENERATE_EPS {
      continue
    }
    let mut span = 0.0
    let mut span_m = 0.0
    for j in 0..<=samples {
      let z = z0 + hstep * Double::from_int(j)
      let a = hhwf_screw_area(h, z)
      let w = if j == 0 || j == samples {
        1.0
      } else if j % 2 == 1 {
        4.0
      } else {
        2.0
      }
      span = span + w * a
      span_m = span_m + w * a * z
    }
    volume = volume + span * hstep / 3.0
    moment = moment + span_m * hstep / 3.0
  }
  if volume <= CAD_DEGENERATE_EPS {
    (0.0, 0.0)
  } else {
    (volume, moment / volume)
  }
}

///|
/// hhwf_screw_perimeter returns the material perimeter at local `z`.
fn hhwf_screw_perimeter(h : HexHeadWasherFace, z : Double) -> Double {
  let g = match hhwf_geometry(h) {
    Some(v) => v
    None => return 0.0
  }
  let r_h = h.shank_diameter_mm / 2.0
  let l = h.shank_length_mm
  let c = if h.tip_chamfer_mm > 0.0 && h.tip_chamfer_mm < r_h {
    h.tip_chamfer_mm
  } else {
    0.0
  }
  if z <= 0.0 {
    let z0 = -l + c
    let r = if z < z0 { r_h - (z0 - z) } else { r_h }
    return 2.0 * @math.PI * r
  }
  let has_w = h.washer_face_diameter_mm > 0.0 && h.washer_face_height_mm > 0.0
  if has_w && z < h.washer_face_height_mm {
    return @math.PI * h.washer_face_diameter_mm
  }
  if z <= g.zb {
    return 2.0 * Double::sqrt(3.0) * h.across_flats_mm
  }
  let period = @math.PI / 3.0
  let cone_r = g.rt + (g.k - z) * g.tan_alpha
  let n = 720
  let step = 2.0 * @math.PI / Double::from_int(n)
  let cos_step = @math.cos(step)
  let rho_at = fn(theta : Double) -> Double {
    let offset = theta - period / 2.0
    let sector = offset - period * Double::floor(offset / period)
    let delta = sector - period / 2.0
    let wall = g.rt / @math.cos(delta)
    if wall < cone_r {
      wall
    } else {
      cone_r
    }
  }
  let mut length = 0.0
  for i in 0..<n {
    let r0 = rho_at(Double::from_int(i) * step)
    let r1 = rho_at(Double::from_int(i + 1) * step)
    length = length + Double::sqrt(r0 * r0 + r1 * r1 - 2.0 * r0 * r1 * cos_step)
  }
  length
}
