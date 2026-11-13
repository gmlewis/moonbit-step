///|
/// RevCircle is a cached circular edge at one profile point.
pub(all) struct RevCircle {
  edge : @step.Ref
  vertex : @step.Ref
  point : @step.Ref
}

///|
/// compile_revolved_profile emits a solid of revolution as one closed STEP
/// solid with analytic `CYLINDRICAL_SURFACE`, `CONICAL_SURFACE`,
/// `SPHERICAL_SURFACE`, `TOROIDAL_SURFACE`, and `PLANE` faces.
///
/// Line bands are cylinders, cones, or planar radial rings/discs. Arc bands are
/// spherical (arc centred on the axis) or toroidal (arc centred off-axis).
/// Every band uses its start circle with oriented-edge sense `.T.` and its end
/// circle with `.F.`, so each shared circle is traversed in opposite directions
/// by the two neighbouring faces. Full-period tube bands carry a seam edge
/// (a straight generator for line bands, a trimmed circular arc for arc bands).
pub fn compile_revolved_profile(
  ctx : StepContext,
  node : SceneNode,
  rev : RevolvedProfile,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  match rev.validate() {
    Err(_) => return []
    Ok(_) => ()
  }
  // Normalize so the material is on the left when walking the profile.
  let raw = rev.segments
  let segs = if rev_profile_signed_area(raw) < 0.0 {
    rev_reverse_segments(raw)
  } else {
    raw
  }
  let axis_dir = xform.apply_dir((0.0, 0.0, 1.0))
  let ref_dir = xform.apply_dir((1.0, 0.0, 0.0))
  let circles : Map[String, RevCircle] = Map([])
  let faces : Array[@step.Ref] = []
  for seg in segs {
    let band = match seg {
      RevLine(a, b) => {
        let info : RevBandInfo = {
          a,
          b,
          center: None,
          sample: ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0),
          normal: rev_line_normal(a, b),
          radial: (a.1 - b.1).abs() < 1.0e-9,
          axial: (a.0 - b.0).abs() < 1.0e-9,
        }
        info
      }
      RevArc(a, b, c) => {
        let (sample, normal) = rev_arc_sample_normal(a, b, c)
        let info : RevBandInfo = {
          a,
          b,
          center: Some(c),
          sample,
          normal,
          radial: false,
          axial: false,
        }
        info
      }
    }
    let face = rev_compile_band(
      ctx,
      xform,
      band,
      axis_dir,
      ref_dir,
      circles,
      reverse~,
    )
    match face {
      Some(f) => faces.push(f)
      None => ()
    }
  }
  faces
}

///|
/// RevBandInfo is the resolved geometry of one profile band.
priv struct RevBandInfo {
  a : Vec2
  b : Vec2
  center : Vec2?
  sample : Vec2
  normal : Vec2
  radial : Bool
  axial : Bool
}

///|
/// rev_line_normal returns the outward 2D normal of a straight band, assuming
/// the material is on the left of the traversal direction.
fn rev_line_normal(a : Vec2, b : Vec2) -> Vec2 {
  let dr = b.0 - a.0
  let dz = b.1 - a.1
  let len = Double::sqrt(dr * dr + dz * dz)
  if len == 0.0 {
    (0.0, 1.0)
  } else {
    (dz / len, -dr / len)
  }
}

///|
/// rev_arc_sample_normal returns the midpoint and outward 2D normal of a minor
/// arc band, assuming the material is on the left of the traversal direction.
fn rev_arc_sample_normal(a : Vec2, b : Vec2, c : Vec2) -> (Vec2, Vec2) {
  let rho = rev_dist2(a, c)
  let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
  let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
  let delta = rev_norm_angle(a1 - a0)
  let am = a0 + delta / 2.0
  let sign = if delta >= 0.0 { 1.0 } else { -1.0 }
  let sample = (c.0 + rho * @math.cos(am), c.1 + rho * @math.sin(am))
  let normal = (sign * @math.cos(am), sign * @math.sin(am))
  (sample, normal)
}

///|
/// rev_reverse_segments reverses a band chain and each band's endpoints.
fn rev_reverse_segments(segs : Array[RevSegment]) -> Array[RevSegment] {
  let out : Array[RevSegment] = []
  let n = segs.length()
  for i in 0..<n {
    let seg = segs[n - 1 - i]
    out.push(
      match seg {
        RevLine(a, b) => RevLine(b, a)
        RevArc(a, b, c) => RevArc(b, a, c)
      },
    )
  }
  out
}

///|
/// rev_get_circle returns the cached circular edge for a profile point.
fn rev_get_circle(
  ctx : StepContext,
  xform : Transform,
  r : Double,
  z : Double,
  circles : Map[String, RevCircle],
) -> RevCircle {
  let key = @step.fmt_num(r) + "," + @step.fmt_num(z)
  match circles.get(key) {
    Some(c) => c
    None => {
      // The CIRCLE axis placement is centred on the revolution axis; the
      // vertex sits on the rim at phi = 0.
      let center = xform.apply((0.0, 0.0, z))
      let center_cp = ctx.cartesian_point(center.0, center.1, center.2)
      let rim = xform.apply((r, 0.0, z))
      let rim_cp = ctx.cartesian_point(rim.0, rim.1, rim.2)
      let up = xform.apply_dir((0.0, 0.0, 1.0))
      let right = xform.apply_dir((1.0, 0.0, 0.0))
      let a2p = ctx.axis2_placement_3d(
        center_cp,
        ctx.direction(up.0, up.1, up.2),
        ctx.direction(right.0, right.1, right.2),
      )
      let circle = ctx.add(
        @repository.any_entity_circle(
          @geometry.Circle::new("", a2p, @step.fmt_num(r)),
        ),
      )
      let vp = ctx.vertex_point(rim_cp)
      let edge = ctx.edge_curve(vp, vp, circle, true)
      let c : RevCircle = { edge, vertex: vp, point: rim_cp, }
      circles.set(key, c)
      c
    }
  }
}

///|
/// rev_compile_band emits the single face for one profile band.
fn rev_compile_band(
  ctx : StepContext,
  xform : Transform,
  band : RevBandInfo,
  axis_dir : Vec3,
  ref_dir : Vec3,
  circles : Map[String, RevCircle],
  reverse~ : Bool = false,
) -> @step.Ref? {
  let ra = band.a.0
  let rb = band.b.0
  let has_a = ra > 1.0e-9
  let has_b = rb > 1.0e-9
  let desired_raw = xform.apply_dir((band.normal.0, 0.0, band.normal.1))
  let sample_world = xform.apply((band.sample.0, 0.0, band.sample.1))
  if band.radial {
    return rev_compile_radial(
      ctx,
      xform,
      band,
      has_a,
      has_b,
      desired_raw,
      circles,
      reverse~,
    )
  }
  // Surface + natural normal.
  let (surface_ref, natural) = rev_band_surface(
    ctx, xform, band, axis_dir, ref_dir, sample_world,
  )
  let dot = v_dot(natural, desired_raw)
  let same_sense = if reverse { !(dot > 0.0) } else { dot > 0.0 }
  if !has_a && !has_b {
    // A band from one axis pole to the other is a full sphere. Emit one
    // spherical face whose boundary is the meridian seam traversed once in
    // each direction. The single face avoids the visible equator crack of a
    // two-hemisphere sphere.
    let pa_world = xform.apply((0.0, 0.0, band.a.1))
    let pb_world = xform.apply((0.0, 0.0, band.b.1))
    let pa_cp = ctx.cartesian_point(pa_world.0, pa_world.1, pa_world.2)
    let pb_cp = ctx.cartesian_point(pb_world.0, pb_world.1, pb_world.2)
    let pa_vp = ctx.vertex_point(pa_cp)
    let pb_vp = ctx.vertex_point(pb_cp)
    let seam = rev_seam_geometry(
      ctx,
      xform,
      band.a,
      band.b,
      pa_vp,
      pb_vp,
      band.center,
    )
    let lp = ctx.edge_loop([
      ctx.oriented_edge(seam, true),
      ctx.oriented_edge(seam, false),
    ])
    let bound = ctx.face_outer_bound(lp, true)
    return Some(ctx.advanced_face([bound], surface_ref, same_sense))
  }
  // Bounds.
  if has_a && has_b {
    let ca = rev_get_circle(ctx, xform, ra, band.a.1, circles)
    let cb = rev_get_circle(ctx, xform, rb, band.b.1, circles)
    let seam = rev_seam_geometry(
      ctx,
      xform,
      band.a,
      band.b,
      ca.vertex,
      cb.vertex,
      band.center,
    )
    let lp = ctx.edge_loop([
      ctx.oriented_edge(seam, true),
      ctx.oriented_edge(cb.edge, false),
      ctx.oriented_edge(seam, false),
      ctx.oriented_edge(ca.edge, true),
    ])
    let bound = ctx.face_outer_bound(lp, true)
    Some(ctx.advanced_face([bound], surface_ref, same_sense))
  } else {
    // The band terminates at a pole. Add an explicit seam from the base rim to
    // the apex vertex so a full-period surface tessellates without an open
    // edge at the singular point.
    let (c, base_is_start, base_pt, pole_pt) = if has_a {
      (rev_get_circle(ctx, xform, ra, band.a.1, circles), true, band.a, band.b)
    } else {
      (rev_get_circle(ctx, xform, rb, band.b.1, circles), false, band.b, band.a)
    }
    let pole = xform.apply((0.0, 0.0, pole_pt.1))
    let pole_cp = ctx.cartesian_point(pole.0, pole.1, pole.2)
    let pole_vp = ctx.vertex_point(pole_cp)
    let seam = rev_seam_geometry(
      ctx,
      xform,
      base_pt,
      pole_pt,
      c.vertex,
      pole_vp,
      band.center,
    )
    let sense = base_is_start
    let lp = ctx.edge_loop([
      ctx.oriented_edge(seam, true),
      ctx.oriented_edge(seam, false),
      ctx.oriented_edge(c.edge, sense),
    ])
    let bound = ctx.face_outer_bound(lp, true)
    Some(ctx.advanced_face([bound], surface_ref, same_sense))
  }
}

///|
/// rev_compile_radial emits a planar disc or annulus face.
fn rev_compile_radial(
  ctx : StepContext,
  xform : Transform,
  band : RevBandInfo,
  has_a : Bool,
  has_b : Bool,
  desired : Vec3,
  circles : Map[String, RevCircle],
  reverse~ : Bool = false,
) -> @step.Ref? {
  let z = band.a.1
  let origin = xform.apply((0.0, 0.0, z))
  let origin_cp = ctx.cartesian_point(origin.0, origin.1, origin.2)
  let refdir = xform.apply_dir((1.0, 0.0, 0.0))
  let a2p = ctx.axis2_placement_3d(
    origin_cp,
    ctx.direction(desired.0, desired.1, desired.2),
    ctx.direction(refdir.0, refdir.1, refdir.2),
  )
  let plane = ctx.add(
    @repository.any_entity_plane(@geometry.Plane::new("", a2p)),
  )
  let same_sense = !reverse
  if has_a && has_b {
    let ca = rev_get_circle(ctx, xform, band.a.0, band.a.1, circles)
    let cb = rev_get_circle(ctx, xform, band.b.0, band.b.1, circles)
    // The start edge uses sense true, the end edge sense false; assign the
    // larger radius to the outer bound.
    let (outer, outer_sense, inner, inner_sense) = if band.a.0 > band.b.0 {
      (ca, true, cb, false)
    } else {
      (cb, false, ca, true)
    }
    let outer_loop = ctx.edge_loop([ctx.oriented_edge(outer.edge, outer_sense)])
    let inner_loop = ctx.edge_loop([ctx.oriented_edge(inner.edge, inner_sense)])
    let outer_bound = ctx.face_outer_bound(outer_loop, true)
    let inner_bound = ctx.face_bound(inner_loop, true)
    Some(ctx.advanced_face([outer_bound, inner_bound], plane, same_sense))
  } else if has_a {
    let ca = rev_get_circle(ctx, xform, band.a.0, band.a.1, circles)
    let lp = ctx.edge_loop([ctx.oriented_edge(ca.edge, true)])
    let bound = ctx.face_outer_bound(lp, true)
    Some(ctx.advanced_face([bound], plane, same_sense))
  } else if has_b {
    let cb = rev_get_circle(ctx, xform, band.b.0, band.b.1, circles)
    let lp = ctx.edge_loop([ctx.oriented_edge(cb.edge, false)])
    let bound = ctx.face_outer_bound(lp, true)
    Some(ctx.advanced_face([bound], plane, same_sense))
  } else {
    None
  }
}

///|
/// rev_band_surface emits the analytic surface for a non-radial band and
/// returns it with the world-space natural normal at the band sample.
fn rev_band_surface(
  ctx : StepContext,
  xform : Transform,
  band : RevBandInfo,
  axis_dir : Vec3,
  ref_dir : Vec3,
  sample_world : Vec3,
) -> (@step.Ref, Vec3) {
  match band.center {
    Some(c) => {
      let rho = rev_dist2(band.a, c)
      // The surface placement origin is the axis point at the arc centre's
      // height; radial offset becomes the major radius (torus) or is zero for
      // a sphere centred on the axis.
      let center_world = xform.apply((c.0, 0.0, c.1))
      let axis_center = xform.apply((0.0, 0.0, c.1))
      let origin_cp = ctx.cartesian_point(
        axis_center.0,
        axis_center.1,
        axis_center.2,
      )
      let a2p = ctx.axis2_placement_3d(
        origin_cp,
        ctx.direction(axis_dir.0, axis_dir.1, axis_dir.2),
        ctx.direction(ref_dir.0, ref_dir.1, ref_dir.2),
      )
      if c.0.abs() < 1.0e-9 {
        let surface = ctx.add(
          @repository.any_entity_spherical_surface(
            @geometry.SphericalSurface::new("", a2p, @step.fmt_num(rho)),
          ),
        )
        let natural = v_norm(v_sub(sample_world, center_world))
        (surface, natural)
      } else {
        let surface = ctx.add(
          @repository.any_entity_toroidal_surface(
            @geometry.ToroidalSurface::new(
              "",
              a2p,
              @step.fmt_num(c.0.abs()),
              @step.fmt_num(rho),
            ),
          ),
        )
        let q = xform.apply((c.0, 0.0, c.1))
        let natural = v_norm(v_sub(sample_world, q))
        (surface, natural)
      }
    }
    None =>
      if band.axial {
        // Cylinder: the axis passes through (0, 0, z_start).
        let r = band.a.0
        let axis_origin = xform.apply((0.0, 0.0, band.a.1))
        let origin_cp = ctx.cartesian_point(
          axis_origin.0,
          axis_origin.1,
          axis_origin.2,
        )
        let a2p = ctx.axis2_placement_3d(
          origin_cp,
          ctx.direction(axis_dir.0, axis_dir.1, axis_dir.2),
          ctx.direction(ref_dir.0, ref_dir.1, ref_dir.2),
        )
        let surface = ctx.add(
          @repository.any_entity_cylindrical_surface(
            @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(r)),
          ),
        )
        let natural = ref_dir
        (surface, natural)
      } else {
        // Cone: place the reference at the endpoint with the larger radius.
        let dr = band.b.0 - band.a.0
        let dz = band.b.1 - band.a.1
        let m = dr / dz
        let alpha = @math.atan(m.abs())
        let axis_sign = if m > 0.0 { 1.0 } else { -1.0 }
        let (ref_r, ref_z) = if band.a.0 >= band.b.0 {
          (band.a.0, band.a.1)
        } else {
          (band.b.0, band.b.1)
        }
        // The placement origin lies on the cone axis; `ref_r` is the radius of
        // the surface at that axial reference plane.
        let axis_point = xform.apply((0.0, 0.0, ref_z))
        let origin_cp = ctx.cartesian_point(
          axis_point.0,
          axis_point.1,
          axis_point.2,
        )
        let cone_axis = v_scale(axis_dir, axis_sign)
        let a2p = ctx.axis2_placement_3d(
          origin_cp,
          ctx.direction(cone_axis.0, cone_axis.1, cone_axis.2),
          ctx.direction(ref_dir.0, ref_dir.1, ref_dir.2),
        )
        // CONICAL_SURFACE's semi-angle is a plane_angle_measure, read in the
        // global context's plane-angle unit, which this writer declares as the
        // radian.
        let surface = ctx.add(
          @repository.any_entity_conical_surface(
            @geometry.ConicalSurface::new(
              "",
              a2p,
              @step.fmt_num(ref_r),
              @step.fmt_num(alpha),
            ),
          ),
        )
        // Natural normal = cos(alpha) * radial - sin(alpha) * axis.
        let natural = v_norm(
          v_sub(
            v_scale(ref_dir, @math.cos(alpha)),
            v_scale(cone_axis, @math.sin(alpha)),
          ),
        )
        (surface, natural)
      }
  }
}

///|
/// rev_seam_geometry returns the seam geometry at the profile plane (phi = 0)
/// from point `a` to point `b`, with the given start/end vertices. Line bands
/// use a straight generator; arc bands use a trimmed circular arc.
fn rev_seam_geometry(
  ctx : StepContext,
  xform : Transform,
  a : Vec2,
  b : Vec2,
  va : @step.Ref,
  vb : @step.Ref,
  center : Vec2?,
) -> @step.Ref {
  match center {
    None => {
      let pa = xform.apply((a.0, 0.0, a.1))
      let pb = xform.apply((b.0, 0.0, b.1))
      let start_cp = ctx.cartesian_point(pa.0, pa.1, pa.2)
      let dir = v_norm(v_sub(pb, pa))
      let dir_ref = ctx.direction(dir.0, dir.1, dir.2)
      let vec_ref = ctx.vector(dir_ref, 1.0)
      let line = ctx.line(start_cp, vec_ref)
      ctx.edge_curve(va, vb, line, true)
    }
    Some(c) => {
      let rho = rev_dist2(a, c)
      let center_world = xform.apply((c.0, 0.0, c.1))
      let origin_cp = ctx.cartesian_point(
        center_world.0,
        center_world.1,
        center_world.2,
      )
      // Axis -Y makes the circle parameter increase from +X toward +Z.
      let seam_axis = xform.apply_dir((0.0, -1.0, 0.0))
      let seam_ref = xform.apply_dir((1.0, 0.0, 0.0))
      let a2p = ctx.axis2_placement_3d(
        origin_cp,
        ctx.direction(seam_axis.0, seam_axis.1, seam_axis.2),
        ctx.direction(seam_ref.0, seam_ref.1, seam_ref.2),
      )
      let circle = ctx.add(
        @repository.any_entity_circle(
          @geometry.Circle::new("", a2p, @step.fmt_num(rho)),
        ),
      )
      let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
      let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
      let delta = rev_norm_angle(a1 - a0)
      // The seam arc is at most a quarter turn, so the two vertices trim the
      // circle unambiguously; the edge sense records the traversal direction.
      ctx.edge_curve(va, vb, circle, delta >= 0.0)
    }
  }
}

///|
/// rev_profile_polyline samples a revolved profile into a polyline in (r, z).
pub fn rev_profile_polyline(
  rev : RevolvedProfile,
  arc_segments~ : Int32 = 12,
) -> Array[Vec2] {
  let pts : Array[Vec2] = []
  let push_unique = fn(p : Vec2) -> Unit {
    match pts.last() {
      Some(q) =>
        if (q.0 - p.0).abs() > 1.0e-9 || (q.1 - p.1).abs() > 1.0e-9 {
          pts.push(p)
        }
      None => pts.push(p)
    }
  }
  for seg in rev.segments {
    match seg {
      RevLine(a, b) => {
        push_unique(a)
        push_unique(b)
      }
      RevArc(a, b, c) => {
        let rho = rev_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = rev_norm_angle(a1 - a0)
        let n = if arc_segments < 2 { 2 } else { arc_segments }
        for i in 0..<=n {
          let t = Double::from_int(i) / Double::from_int(n)
          let ang = a0 + delta * t
          push_unique((c.0 + rho * @math.cos(ang), c.1 + rho * @math.sin(ang)))
        }
      }
    }
  }
  pts
}

///|
/// rev_mesh builds a triangle/quad mesh approximation of a revolved profile for
/// the optional Blender export. STEP output uses the analytic compiler, not
/// this mesh.
pub fn rev_mesh(
  rev : RevolvedProfile,
  angular_segments~ : Int32 = 48,
  arc_segments~ : Int32 = 12,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let profile = rev_profile_polyline(rev, arc_segments~)
  let m = profile.length()
  let k = if angular_segments < 8 { 8 } else { angular_segments }
  let verts : Array[Vec3] = []
  for j in 0..<k {
    let theta = 2.0 * @math.PI * Double::from_int(j) / Double::from_int(k)
    let ct = @math.cos(theta)
    let st = @math.sin(theta)
    for i in 0..<m {
      let (r, z) = profile[i]
      verts.push((r * ct, r * st, z))
    }
  }
  let faces : Array[Array[Int32]] = []
  let idx = fn(j : Int32, i : Int32) -> Int32 { j * m + i }
  for j in 0..<k {
    let jn = (j + 1) % k
    for i in 0..<(m - 1) {
      let ra = profile[i].0
      let rb = profile[i + 1].0
      let eps = 1.0e-9
      if ra < eps && rb < eps {
        continue
      } else if ra < eps {
        // Pole at the start: emit a triangle fan cap.
        faces.push([idx(j, i), idx(jn, i + 1), idx(j, i + 1)])
      } else if rb < eps {
        faces.push([idx(j, i), idx(jn, i), idx(jn, i + 1)])
      } else {
        faces.push([idx(j, i), idx(jn, i), idx(jn, i + 1), idx(j, i + 1)])
      }
    }
  }
  (verts, faces)
}
