///|
/// ExtrudedArcProfile::new builds an extruded closed line-plus-arc profile.
pub fn ExtrudedArcProfile::new(
  segments : Array[ProfileSegment],
  height_mm : Double,
  round_bore? : (Vec2, Double),
) -> ExtrudedArcProfile {
  { segments, height_mm, round_bore, }
}

///|
/// ExtrudedArcProfile::as_shape wraps the profile as a `Shape`.
pub fn ExtrudedArcProfile::as_shape(self : ExtrudedArcProfile) -> Shape {
  Shape::ExtrudedArcProfile(self)
}

///|
fn arc_dist2(a : Vec2, b : Vec2) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  Double::sqrt(dx * dx + dy * dy)
}

///|
/// arc_norm_sweep normalizes an angular difference to `[0, 2*pi)`.
fn arc_norm_sweep(a : Double) -> Double {
  let two_pi = 2.0 * @math.PI
  let mut x = a
  while x < 0.0 {
    x = x + two_pi
  }
  while x >= two_pi {
    x = x - two_pi
  }
  x
}

///|
fn arc_seg_start(seg : ProfileSegment) -> Vec2 {
  match seg {
    SegmentLine(a, _) => a
    SegmentArc(a, _, _) => a
  }
}

///|
fn arc_seg_end(seg : ProfileSegment) -> Vec2 {
  match seg {
    SegmentLine(_, b) => b
    SegmentArc(_, b, _) => b
  }
}

///|
fn arc_close2(a : Vec2, b : Vec2) -> Bool {
  (a.0 - b.0).abs() < CAD_LENGTH_EPS && (a.1 - b.1).abs() < CAD_LENGTH_EPS
}

///|
/// ExtrudedArcProfile::validate checks that the segments form one closed
/// counter-clockwise loop of lines and counter-clockwise minor arcs.
pub fn ExtrudedArcProfile::validate(self : ExtrudedArcProfile) -> Bool {
  let segs = self.segments
  let n = segs.length()
  if n < 3 || self.height_mm <= 0.0 {
    return false
  }
  for i in 0..<n {
    let seg = segs[i]
    let a = arc_seg_start(seg)
    let b = arc_seg_end(seg)
    if arc_close2(a, b) {
      return false
    }
    match seg {
      SegmentLine(_, _) => ()
      SegmentArc(_, _, c) => {
        let r1 = arc_dist2(a, c)
        let r2 = arc_dist2(b, c)
        if r1 < CAD_DEGENERATE_EPS || (r1 - r2).abs() > CAD_ANGLE_EPS {
          return false
        }
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = arc_norm_sweep(a1 - a0)
        if delta <= CAD_DEGENERATE_EPS || delta > @math.PI + CAD_ANGLE_EPS {
          return false
        }
      }
    }
    if i > 0 && !arc_close2(arc_seg_end(segs[i - 1]), a) {
      return false
    }
  }
  if !arc_close2(arc_seg_end(segs[n - 1]), arc_seg_start(segs[0])) {
    return false
  }
  arc_profile_signed_area(segs) > CAD_DEGENERATE_EPS
}

///|
/// arc_profile_signed_area returns the signed area of a line-plus-arc loop.
/// Positive means counter-clockwise.
fn arc_profile_signed_area(segs : Array[ProfileSegment]) -> Double {
  let mut sum = 0.0
  for seg in segs {
    let a = arc_seg_start(seg)
    let b = arc_seg_end(seg)
    sum = sum + a.0 * b.1 - b.0 * a.1
    match seg {
      SegmentLine(_, _) => ()
      SegmentArc(_, _, c) => {
        let rho = arc_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = arc_norm_sweep(a1 - a0)
        sum = sum + rho * rho * (delta - @math.sin(delta))
      }
    }
  }
  sum / 2.0
}

///|
/// arc_profile_area_moments returns the exact area and first moments of a
/// line-plus-arc loop by Green's theorem.
fn arc_profile_area_moments(
  segs : Array[ProfileSegment],
) -> (Double, Double, Double) {
  let mut area2 = 0.0
  let mut mx2 = 0.0
  let mut my2 = 0.0
  for seg in segs {
    let a = arc_seg_start(seg)
    let b = arc_seg_end(seg)
    area2 = area2 + a.0 * b.1 - b.0 * a.1
    match seg {
      SegmentLine(_, _) => {
        // Boundary integrals along the straight chord.
        mx2 = mx2 + (b.1 - a.1) * (a.0 * a.0 + a.0 * b.0 + b.0 * b.0) / 3.0
        my2 = my2 - (b.0 - a.0) * (a.1 * a.1 + a.1 * b.1 + b.1 * b.1) / 3.0
      }
      SegmentArc(_, _, c) => {
        // Replace the chord integrals with the exact circular-arc integrals.
        let rho = arc_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = arc_norm_sweep(a1 - a0)
        let t1 = a1
        let t0 = a1 - delta
        let dtsin = @math.sin(t1) - @math.sin(t0)
        let dtcos = @math.cos(t0) - @math.cos(t1)
        let dt2sin = @math.sin(2.0 * t1) - @math.sin(2.0 * t0)
        let ic2 = delta / 2.0 + dt2sin / 4.0
        let is2 = delta / 2.0 - dt2sin / 4.0
        let ic3 = dtsin -
          (
            @math.sin(t1) * @math.sin(t1) * @math.sin(t1) -
            @math.sin(t0) * @math.sin(t0) * @math.sin(t0)
          ) /
          3.0
        let is3 = dtcos +
          (
            @math.cos(t1) * @math.cos(t1) * @math.cos(t1) -
            @math.cos(t0) * @math.cos(t0) * @math.cos(t0)
          ) /
          3.0
        area2 = area2 + rho * rho * (delta - @math.sin(delta))
        mx2 = mx2 +
          rho * (c.0 * c.0 * dtsin + 2.0 * c.0 * rho * ic2 + rho * rho * ic3)
        my2 = my2 +
          rho * (c.1 * c.1 * dtcos + 2.0 * c.1 * rho * is2 + rho * rho * is3)
      }
    }
  }
  (area2 / 2.0, mx2 / 2.0, my2 / 2.0)
}

///|
/// arc_profile_perimeter returns the exact boundary length.
fn arc_profile_perimeter(segs : Array[ProfileSegment]) -> Double {
  let mut total = 0.0
  for seg in segs {
    let a = arc_seg_start(seg)
    let b = arc_seg_end(seg)
    match seg {
      SegmentLine(_, _) => total = total + arc_dist2(a, b)
      SegmentArc(_, _, c) => {
        let rho = arc_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        total = total + rho * arc_norm_sweep(a1 - a0)
      }
    }
  }
  total
}

///|
/// arc_profile_max_radius returns the largest distance from the local origin to
/// the boundary (sampling arcs).
fn arc_profile_max_radius(segs : Array[ProfileSegment]) -> Double {
  let mut rmax = 0.0
  let take = fn(x : Double, y : Double) -> Unit {
    let r = Double::sqrt(x * x + y * y)
    if r > rmax {
      rmax = r
    }
  }
  for seg in segs {
    let a = arc_seg_start(seg)
    let b = arc_seg_end(seg)
    take(a.0, a.1)
    take(b.0, b.1)
    match seg {
      SegmentLine(_, _) => ()
      SegmentArc(_, _, c) => {
        let rho = arc_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = arc_norm_sweep(a1 - a0)
        for k in 0..<=32 {
          let t = Double::from_int(k) / 32.0
          let ang = a0 + delta * t
          take(c.0 + rho * @math.cos(ang), c.1 + rho * @math.sin(ang))
        }
      }
    }
  }
  rmax
}

///|
/// ExtrudedArcProfile::volume returns the exact volume.
pub fn ExtrudedArcProfile::volume(self : ExtrudedArcProfile) -> Double {
  let (area, _mx, _my) = arc_profile_area_moments(self.segments)
  let mut a = area
  match self.round_bore {
    Some((_c, d)) => {
      let rb = d / 2.0
      a = a - @math.PI * rb * rb
    }
    None => ()
  }
  if a <= 0.0 {
    0.0
  } else {
    a * self.height_mm
  }
}

///|
/// ExtrudedArcProfile::centroid returns the exact centroid in the local frame.
pub fn ExtrudedArcProfile::centroid(self : ExtrudedArcProfile) -> Vec3 {
  let (area, mx, my) = arc_profile_area_moments(self.segments)
  let mut a = area
  let mut mx2 = mx
  let mut my2 = my
  match self.round_bore {
    Some((c, d)) => {
      let rb = d / 2.0
      let ba = @math.PI * rb * rb
      a = a - ba
      mx2 = mx2 - ba * c.0
      my2 = my2 - ba * c.1
    }
    None => ()
  }
  if a <= CAD_DEGENERATE_EPS {
    (0.0, 0.0, 0.0)
  } else {
    (mx2 / a, my2 / a, self.height_mm / 2.0)
  }
}

///|
/// an_extruded_arc_inventory mirrors the compiler's face emission.
fn an_extruded_arc_inventory(e : ExtrudedArcProfile) -> SurfaceInventory {
  if !e.validate() {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  let mut planes = 2
  let mut cylinders = 0
  for seg in e.segments {
    match seg {
      SegmentLine(_, _) => planes = planes + 1
      SegmentArc(_, _, _) => cylinders = cylinders + 1
    }
  }
  match e.round_bore {
    Some((_c, d)) => if d > 0.0 { cylinders = cylinders + 1 }
    None => ()
  }
  an_inventory(planes, cylinders, 0, 0, 0, 0, 0, 0)
}

///|
/// an_extruded_arc_section returns the exact section at local `z`.
fn an_extruded_arc_section(
  e : ExtrudedArcProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  if !e.validate() {
    return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > e.height_mm + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  let (area, _mx, _my) = arc_profile_area_moments(e.segments)
  let mut a = area
  let mut p = arc_profile_perimeter(e.segments)
  let outer = arc_profile_max_radius(e.segments)
  let mut inner = 0.0
  match e.round_bore {
    Some((_c, d)) => {
      let rb = d / 2.0
      a = a - @math.PI * rb * rb
      p = p + 2.0 * @math.PI * rb
      inner = rb
    }
    None => ()
  }
  if a <= CAD_DEGENERATE_EPS {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: a,
    perimeter_mm: p,
    outer_radius_mm: outer,
    inner_radius_mm: inner,
    rings: [{ inner_radius_mm: inner, outer_radius_mm: outer, }],
  })
}

///|
/// extruded_arc_mesh builds a visualization mesh by sampling the arcs.
pub fn extruded_arc_mesh(
  e : ExtrudedArcProfile,
  arc_segments~ : Int32 = 24,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let n = if arc_segments < 2 { 2 } else { arc_segments }
  let outer : Array[Vec2] = []
  for seg in e.segments {
    match seg {
      SegmentLine(a, _) => outer.push(a)
      SegmentArc(a, b, c) => {
        let rho = arc_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = arc_norm_sweep(a1 - a0)
        for k in 0..<n {
          let t = Double::from_int(k) / Double::from_int(n)
          let ang = a0 + delta * t
          outer.push((c.0 + rho * @math.cos(ang), c.1 + rho * @math.sin(ang)))
        }
      }
    }
  }
  let holes : Array[Array[Vec2]] = []
  match e.round_bore {
    Some((c, d)) => {
      let rb = d / 2.0
      let h : Array[Vec2] = []
      let count = 48
      for k in 0..<count {
        let th = 2.0 * @math.PI * Double::from_int(k) / Double::from_int(count)
        h.push((c.0 + rb * @math.cos(th), c.1 + rb * @math.sin(th)))
      }
      holes.push(h.rev())
    }
    None => ()
  }
  an_extruded_mesh({
    profile: { outer, holes, },
    height_mm: e.height_mm,
    round_bore: None,
  })
}

///|
/// compile_extruded_arc_profile emits one closed solid with analytic cylindrical
/// faces for every circular arc and planar faces for every line and cap.
pub fn compile_extruded_arc_profile(
  ctx : StepContext,
  node : SceneNode,
  e : ExtrudedArcProfile,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  if !e.validate() {
    return []
  }
  let xform = node_transform(node, parent)
  let segs = e.segments
  let n = segs.length()
  let h = e.height_mm
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let pts_raw : Array[Vec3] = []
  for seg in segs {
    let p = arc_seg_start(seg)
    pts_raw.push((p.0, p.1, 0.0))
  }
  for seg in segs {
    let p = arc_seg_start(seg)
    pts_raw.push((p.0, p.1, h))
  }
  let pts = pts_raw.map(fn(pt) { xform.apply(pt) })
  let cp_refs = pts.map(fn(pt) {
    let (px, py, pz) = pt
    ctx.cartesian_point(px, py, pz)
  })
  let vp_refs = cp_refs.map(fn(cp) { ctx.vertex_point(cp) })
  let edges : Array[EdgeInfo] = []
  let add_line = fn(a : Int32, b : Int32) -> Unit {
    let dir_raw = v_norm(v_sub(pts[b], pts[a]))
    let dir_ref = ctx.direction(dir_raw.0, dir_raw.1, dir_raw.2)
    let vec_ref = ctx.vector(dir_ref, 1.0)
    let line_ref = ctx.line(cp_refs[a], vec_ref)
    let ec_ref = ctx.edge_curve(vp_refs[a], vp_refs[b], line_ref, true)
    edges.push(EdgeInfo::{ start: a, end: b, edge: ec_ref, })
  }
  let add_arc = fn(a : Int32, b : Int32, c : Vec2, z : Double) -> Unit {
    let rho = arc_dist2(arc_seg_start(segs[a % n]), c)
    let center = xform.apply((c.0, c.1, z))
    let center_cp = ctx.cartesian_point(center.0, center.1, center.2)
    let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
    let circle = ctx.add(
      @repository.any_entity_circle(
        @geometry.Circle::new("", a2p, @step.fmt_num(rho)),
      ),
    )
    let ec_ref = ctx.edge_curve(vp_refs[a], vp_refs[b], circle, true)
    edges.push(EdgeInfo::{ start: a, end: b, edge: ec_ref, })
  }
  for i in 0..<n {
    let j = (i + 1) % n
    match segs[i] {
      SegmentLine(_, _) => {
        add_line(i, j)
        add_line(n + i, n + j)
      }
      SegmentArc(_, _, c) => {
        add_arc(i, j, c, 0.0)
        add_arc(n + i, n + j, c, h)
      }
    }
    add_line(i, n + i)
  }
  // Cap outer loops.
  let top_cycle : Array[Int32] = []
  for i in 0..<n {
    top_cycle.push(n + i)
  }
  let bottom_rev : Array[Int32] = []
  for i in 0..<n {
    bottom_rev.push(n - 1 - i)
  }
  let top_loop = face_loop(ctx, edges, top_cycle)
  let bottom_loop = face_loop(ctx, edges, bottom_rev)
  let t0 = pts[n]
  let top_origin = ctx.cartesian_point(t0.0, t0.1, t0.2)
  let b0 = pts[0]
  let bottom_origin = ctx.cartesian_point(b0.0, b0.1, b0.2)
  let faces : Array[@step.Ref] = []
  // Analytic circular bore, if any.
  let bottom_holes : Array[@step.Ref] = []
  let top_holes : Array[@step.Ref] = []
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let cb = xform.apply((center.0, center.1, 0.0))
      let ct = xform.apply((center.0, center.1, h))
      let cp_b = ctx.cartesian_point(cb.0, cb.1, cb.2)
      let cp_t = ctx.cartesian_point(ct.0, ct.1, ct.2)
      let a2p_b = ctx.axis2_placement_3d(cp_b, dir_up, dir_right)
      let a2p_t = ctx.axis2_placement_3d(cp_t, dir_up, dir_right)
      let radius = @step.fmt_num(rb)
      let circle_b = ctx.add(
        @repository.any_entity_circle(@geometry.Circle::new("", a2p_b, radius)),
      )
      let circle_t = ctx.add(
        @repository.any_entity_circle(@geometry.Circle::new("", a2p_t, radius)),
      )
      let cylinder = ctx.add(
        @repository.any_entity_cylindrical_surface(
          @geometry.CylindricalSurface::new("", a2p_b, radius),
        ),
      )
      let seam_b = xform.apply((center.0 + rb, center.1, 0.0))
      let seam_t = xform.apply((center.0 + rb, center.1, h))
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
      let e_b = ctx.edge_curve(vp_sb, vp_sb, circle_b, true)
      let e_t = ctx.edge_curve(vp_st, vp_st, circle_t, true)
      let lateral_loop = ctx.edge_loop([
        ctx.oriented_edge(seam, true),
        ctx.oriented_edge(e_t, true),
        ctx.oriented_edge(seam, false),
        ctx.oriented_edge(e_b, false),
      ])
      faces.push(
        ctx.advanced_face(
          [ctx.face_outer_bound(lateral_loop, true)],
          cylinder,
          reverse,
        ),
      )
      bottom_holes.push(ctx.edge_loop([ctx.oriented_edge(e_b, true)]))
      top_holes.push(ctx.edge_loop([ctx.oriented_edge(e_t, false)]))
    }
    None => ()
  }
  faces.push(
    add_plane_face_from_loops(
      ctx,
      bottom_origin,
      down,
      right,
      bottom_loop,
      bottom_holes,
      reverse~,
    ),
  )
  faces.push(
    add_plane_face_from_loops(
      ctx,
      top_origin,
      up,
      right,
      top_loop,
      top_holes,
      reverse~,
    ),
  )
  // Side faces.
  for i in 0..<n {
    let j = (i + 1) % n
    match segs[i] {
      SegmentLine(_, _) => {
        let p0 = pts[i]
        let p1 = pts[j]
        let p2 = pts[n + i]
        let expected = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
        faces.push(
          add_plane_face_oriented(
            ctx,
            edges,
            pts,
            cp_refs,
            [i, j, n + j, n + i],
            expected,
            reverse~,
          ),
        )
      }
      SegmentArc(_, _, c) => {
        let rho = arc_dist2(arc_seg_start(segs[i]), c)
        let center = xform.apply((c.0, c.1, 0.0))
        let center_cp = ctx.cartesian_point(center.0, center.1, center.2)
        let a2p = ctx.axis2_placement_3d(center_cp, dir_up, dir_right)
        let cylinder = ctx.add(
          @repository.any_entity_cylindrical_surface(
            @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(rho)),
          ),
        )
        let (eb, _) = find_edge(edges, i, j)
        let (et, _) = find_edge(edges, n + i, n + j)
        let (ve, _) = find_edge(edges, j, n + j)
        let (vs, _) = find_edge(edges, i, n + i)
        let loop_ref = ctx.edge_loop([
          ctx.oriented_edge(eb, true),
          ctx.oriented_edge(ve, true),
          ctx.oriented_edge(et, false),
          ctx.oriented_edge(vs, false),
        ])
        faces.push(
          ctx.advanced_face(
            [ctx.face_outer_bound(loop_ref, true)],
            cylinder,
            !reverse,
          ),
        )
      }
    }
  }
  faces
}
