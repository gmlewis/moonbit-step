///|
// Native smooth B-rep for a rectangular profile swept along a helical path.
//
// The four sides of the swept strip are ruled B-spline surfaces between the
// four corner helices (cubic Bezier spans with exact endpoint tangents), and
// the two ends are planar caps. The result is the six-face topology of a
// spring-washer STEP reference rather than a stack of planar facets.
//
// The corner paths are sampled from the sweep path; the curve control points
// use cubic Hermite spans, so the emitted surfaces deviate from the ideal
// helix by only a few 1e-5 mm at 24 spans per turn.

///|
priv struct SmoothCurve {
  curve_ref : @step.Ref
  cps : Array[@step.Ref]
  cps_pos : Array[Vec3]
  start_cp : @step.Ref
  end_cp : @step.Ref
}

///|
fn smooth_round(x : Double) -> Int32 {
  (x + 0.5).to_int()
}

///|
fn smooth_average(points : Array[Vec3]) -> Vec3 {
  let mut x = 0.0
  let mut y = 0.0
  let mut z = 0.0
  let n = points.length()
  for p in points {
    x = x + p.0
    y = y + p.1
    z = z + p.2
  }
  let d = n.to_double()
  (x / d, y / d, z / d)
}

///|
fn smooth_polygon_normal(points : Array[Vec3]) -> Vec3 {
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
fn smooth_curve(
  ctx : StepContext,
  corner_pts : Array[Vec3],
  indices : Array[Int32],
  profile_index : Int32,
  num_path_pts : Int32,
  v_mults : Array[Int32],
  v_knots : Array[String],
  stride~ : Int32 = 4,
  sharp_creases~ : Array[Int32] = [],
) -> SmoothCurve {
  let num_spans = indices.length() - 1
  let point_at = fn(idx : Int32) -> Vec3 {
    corner_pts[idx * stride + profile_index]
  }
  let points : Array[Vec3] = Array::make(num_spans + 1, (0.0, 0.0, 0.0))
  for k in 0..<=num_spans {
    points[k] = point_at(indices[k])
  }
  let is_crease = fn(idx : Int32) -> Bool {
    for c in sharp_creases {
      if c == idx {
        return true
      }
    }
    false
  }
  let control_pts : Array[Vec3] = []
  for k in 0..<num_spans {
    let ia = indices[k]
    let ib = indices[k + 1]
    let p0 = points[k]
    let p3 = points[k + 1]
    let delta = (ib - ia).to_double()
    // A crease (or an end of the path) uses the one-sided chord tangent, so
    // the two Bezier spans meeting there form a sharp corner instead of a
    // wave.
    let t_start = if ia == 0 || is_crease(ia) {
      v_sub(point_at(ib), point_at(ia))
    } else {
      v_scale(v_sub(point_at(ia + 1), point_at(ia - 1)), 0.5)
    }
    let t_end = if ib == num_path_pts - 1 || is_crease(ib) {
      v_sub(point_at(ib), point_at(ia))
    } else {
      v_scale(v_sub(point_at(ib + 1), point_at(ib - 1)), 0.5)
    }
    let p1 = v_add(p0, v_scale(t_start, delta / 3.0))
    let p2 = v_sub(p3, v_scale(t_end, delta / 3.0))
    if k == 0 {
      control_pts.push(p0)
    }
    control_pts.push(p1)
    control_pts.push(p2)
    control_pts.push(p3)
  }
  let cps = control_pts.map(fn(p) { ctx.cartesian_point(p.0, p.1, p.2) })
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", 3, cps, ".UNSPECIFIED.", false, false, v_mults, v_knots, ".PIECEWISE_BEZIER_KNOTS.",
  )
  let curve_ref = ctx.add(
    @repository.any_entity_b_spline_curve_with_knots(curve),
  )
  {
    curve_ref,
    cps,
    cps_pos: control_pts,
    start_cp: cps[0],
    end_cp: cps[cps.length() - 1],
  }
}

///|
fn smooth_surface(
  ctx : StepContext,
  row_a : SmoothCurve,
  row_b : SmoothCurve,
  expected_out : Vec3,
  v_mults : Array[Int32],
  v_knots : Array[String],
) -> (@step.Ref, Bool) {
  let du = v_sub(row_b.cps_pos[0], row_a.cps_pos[0])
  let dv = v_sub(row_a.cps_pos[1], row_a.cps_pos[0])
  let natural_normal = v_cross(du, dv)
  // Orient the surface patch so its natural normal points outward; the face
  // then uses same_sense = .T. for every patch (the reference form).
  let (row0, row1) = if v_dot(natural_normal, expected_out) >= 0.0 {
    (row_a, row_b)
  } else {
    (row_b, row_a)
  }
  let cp_row = fn(row : Array[@step.Ref]) -> String {
    "(" + row.map(fn(r) { "#\{r.id.value}" }).join(",") + ")"
  }
  let rows = "(" + cp_row(row0.cps) + "," + cp_row(row1.cps) + ")"
  let v_mults_text = "(" + v_mults.map(fn(m) { "\{m}" }).join(",") + ")"
  let v_knots_text = "(" + v_knots.join(",") + ")"
  // Emit the AP214 simple-entity form used by the downloaded references:
  // B_SPLINE_SURFACE_WITH_KNOTS('',u_deg,v_deg,((row0),(row1)),...).
  let args = "('',1,3," +
    rows +
    ",.UNSPECIFIED.,.F.,.F.,.F.,(2,2)," +
    v_mults_text +
    ",(0.,1.)," +
    v_knots_text +
    ",.PIECEWISE_BEZIER_KNOTS.)"
  let raw = @step.RawEntity::new("B_SPLINE_SURFACE_WITH_KNOTS", args)
  let surface_ref = ctx.add(@repository.any_entity_raw_entity(raw))
  (surface_ref, true)
}

///|
fn smooth_line_edge(
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
fn smooth_cap_plane(
  ctx : StepContext,
  outward : Vec3,
  location : Vec3,
  reference : Vec3,
) -> @step.Ref {
  let location_ref = ctx.cartesian_point(location.0, location.1, location.2)
  let axis_ref = ctx.direction(outward.0, outward.1, outward.2)
  let ref_ref = ctx.direction(reference.0, reference.1, reference.2)
  let placement = ctx.axis2_placement_3d(location_ref, axis_ref, ref_ref)
  let plane = @geometry.Plane::new("", placement)
  ctx.add(@repository.any_entity_plane(plane))
}

///|
fn smooth_face(
  ctx : StepContext,
  edges : Array[(@step.Ref, Bool)],
  surface : @step.Ref,
  same_sense : Bool,
) -> @step.Ref {
  // Build the loop with the orientation that agrees with the surface normal;
  // reversing the caller's cycle keeps every shared edge opposite.
  let reversed = edges.rev().map(fn(e) { (e.0, !e.1) })
  let oriented = reversed.map(fn(e) { ctx.oriented_edge(e.0, e.1) })
  let edge_loop_ref = ctx.edge_loop(oriented)
  let bound = ctx.face_outer_bound(edge_loop_ref, true)
  ctx.advanced_face([bound], surface, same_sense)
}

///|
fn compile_smooth_helix(
  ctx : StepContext,
  node : SceneNode,
  s : SweptProfile,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let path = s.path
  let profile = s.profile
  let num_path_pts = path.points.length()
  if num_path_pts < 4 || profile.vertices.length() != 4 {
    return []
  }
  let xform = node_transform(node, parent)

  // Profile-local coordinates (the same mapping the faceted sweep uses).
  let prof_z = v_norm(profile.normal_dir)
  let prof_x = v_norm(profile.right_dir)
  let prof_y = v_norm(v_cross(prof_z, prof_x))
  let m_global_to_prof = Matrix3x3::{
    m00: prof_x.0,
    m01: prof_x.1,
    m02: prof_x.2,
    m10: prof_y.0,
    m11: prof_y.1,
    m12: prof_y.2,
    m20: prof_z.0,
    m21: prof_z.1,
    m22: prof_z.2,
  }
  let local_verts = profile.vertices.map(fn(v) {
    apply_matrix(m_global_to_prof, v_sub(v, profile.center))
  })

  // Corner positions at every path point, in world coordinates.
  let corner_pts : Array[Vec3] = Array::make(num_path_pts * 4, (0.0, 0.0, 0.0))
  for i in 0..<num_path_pts {
    let p_origin = path.points[i]
    let p_tangent = v_norm(path.tangents[i])
    let p_normal = v_norm(path.normals[i])
    let p_right = v_norm(v_cross(p_tangent, p_normal))
    let m_path_to_global = Matrix3x3::{
      m00: p_right.0,
      m01: p_normal.0,
      m02: p_tangent.0,
      m10: p_right.1,
      m11: p_normal.1,
      m12: p_tangent.1,
      m20: p_right.2,
      m21: p_normal.2,
      m22: p_tangent.2,
    }
    for j, v in local_verts {
      let gv = apply_matrix(m_path_to_global, v)
      let world = (gv.0 + p_origin.0, gv.1 + p_origin.1, gv.2 + p_origin.2)
      corner_pts[i * 4 + j] = xform.apply(world)
    }
  }

  // Classify the four profile corners once: 0=inner-top, 1=inner-bottom,
  // 2=outer-top, 3=outer-bottom.
  let first_origin = path.points[0]
  let first_radius = Double::sqrt(
    first_origin.0 * first_origin.0 + first_origin.1 * first_origin.1,
  )
  let role_index : Array[Int32] = Array::make(4, -1)
  for j in 0..<4 {
    let p = corner_pts[j]
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    let z_off = p.2 - xform.apply(first_origin).2
    let radial = if r < first_radius { 0 } else { 1 }
    let axial = if z_off > 0.0 { 0 } else { 1 }
    role_index[radial * 2 + axial] = j
  }
  for role in 0..<4 {
    if role_index[role] < 0 {
      return []
    }
  }

  // Optional reference corner endpoints: blend the sampled corner curves so
  // they meet the given high-Z and low-Z cap vertices exactly. The correction
  // is expressed in the local (radial, axial, tangential) sweep frame so it
  // rotates with the helix instead of distorting the far side of the ring.
  match s.corner_override {
    Some((start_ref, end_ref)) =>
      if start_ref.length() == 4 && end_ref.length() == 4 {
        let start_t = xform.apply_dir(v_norm(path.tangents[0]))
        let start_n = xform.apply_dir(v_norm(path.normals[0]))
        let start_r = v_norm(v_cross(start_t, start_n))
        let last = num_path_pts - 1
        let end_t = xform.apply_dir(v_norm(path.tangents[last]))
        let end_n = xform.apply_dir(v_norm(path.normals[last]))
        let end_r = v_norm(v_cross(end_t, end_n))
        for role in 0..<4 {
          let j = role_index[role]
          let start_delta = v_sub(xform.apply(start_ref[role]), corner_pts[j])
          let end_delta = v_sub(
            xform.apply(end_ref[role]),
            corner_pts[last * 4 + j],
          )
          let s_lx = v_dot(start_delta, start_r)
          let s_ly = v_dot(start_delta, start_n)
          let s_lz = v_dot(start_delta, start_t)
          let e_lx = v_dot(end_delta, end_r)
          let e_ly = v_dot(end_delta, end_n)
          let e_lz = v_dot(end_delta, end_t)
          for i in 0..<num_path_pts {
            let t = i.to_double() / last.to_double()
            let u = 1.0 - t
            let tangent = xform.apply_dir(v_norm(path.tangents[i]))
            let normal = xform.apply_dir(v_norm(path.normals[i]))
            let right = v_norm(v_cross(tangent, normal))
            let correction = v_add(
              v_add(
                v_scale(right, s_lx * u + e_lx * t),
                v_scale(normal, s_ly * u + e_ly * t),
              ),
              v_scale(tangent, s_lz * u + e_lz * t),
            )
            corner_pts[i * 4 + j] = v_add(corner_pts[i * 4 + j], correction)
          }
        }
      }
    None => ()
  }

  // Total sweep angle, then one cubic span per 15 degrees (24 per turn).
  let mut total_angle = 0.0
  for i in 0..<(num_path_pts - 1) {
    let a = path.points[i]
    let b = path.points[i + 1]
    let cross_z = a.0 * b.1 - a.1 * b.0
    let dot = a.0 * b.0 + a.1 * b.1
    total_angle = total_angle + @math.atan2(cross_z, dot)
  }
  let turns = Double::abs(total_angle) / (2.0 * @math.PI)
  let mut num_spans = smooth_round(turns * 24.0)
  if num_spans < 4 {
    num_spans = 4
  }
  if num_spans > num_path_pts - 1 {
    num_spans = num_path_pts - 1
  }
  let indices : Array[Int32] = Array::make(num_spans + 1, 0)
  for k in 0..<=num_spans {
    indices[k] = smooth_round(
      k.to_double() * (num_path_pts - 1).to_double() / num_spans.to_double(),
    )
  }
  let v_mults : Array[Int32] = [4]
  for _ in 1..<num_spans {
    v_mults.push(3)
  }
  v_mults.push(4)
  let v_knots : Array[String] = []
  for i in 0..<=num_spans {
    v_knots.push(@step.fmt_num(i.to_double()))
  }

  let it = smooth_curve(
    ctx,
    corner_pts,
    indices,
    role_index[0],
    num_path_pts,
    v_mults,
    v_knots,
  )
  let ib = smooth_curve(
    ctx,
    corner_pts,
    indices,
    role_index[1],
    num_path_pts,
    v_mults,
    v_knots,
  )
  let ot = smooth_curve(
    ctx,
    corner_pts,
    indices,
    role_index[2],
    num_path_pts,
    v_mults,
    v_knots,
  )
  let ob = smooth_curve(
    ctx,
    corner_pts,
    indices,
    role_index[3],
    num_path_pts,
    v_mults,
    v_knots,
  )

  let vp_it_s = ctx.vertex_point(it.start_cp)
  let vp_it_e = ctx.vertex_point(it.end_cp)
  let vp_ib_s = ctx.vertex_point(ib.start_cp)
  let vp_ib_e = ctx.vertex_point(ib.end_cp)
  let vp_ot_s = ctx.vertex_point(ot.start_cp)
  let vp_ot_e = ctx.vertex_point(ot.end_cp)
  let vp_ob_s = ctx.vertex_point(ob.start_cp)
  let vp_ob_e = ctx.vertex_point(ob.end_cp)

  let he_it = ctx.edge_curve(vp_it_s, vp_it_e, it.curve_ref, true)
  let he_ib = ctx.edge_curve(vp_ib_s, vp_ib_e, ib.curve_ref, true)
  let he_ot = ctx.edge_curve(vp_ot_s, vp_ot_e, ot.curve_ref, true)
  let he_ob = ctx.edge_curve(vp_ob_s, vp_ob_e, ob.curve_ref, true)

  let s_top_s = smooth_line_edge(
    ctx,
    it.start_cp,
    vp_it_s,
    ot.start_cp,
    vp_ot_s,
    it.cps_pos[0],
    ot.cps_pos[0],
  )
  let s_bot_s = smooth_line_edge(
    ctx,
    ib.start_cp,
    vp_ib_s,
    ob.start_cp,
    vp_ob_s,
    ib.cps_pos[0],
    ob.cps_pos[0],
  )
  let s_it_s = smooth_line_edge(
    ctx,
    it.start_cp,
    vp_it_s,
    ib.start_cp,
    vp_ib_s,
    it.cps_pos[0],
    ib.cps_pos[0],
  )
  let s_ot_s = smooth_line_edge(
    ctx,
    ot.start_cp,
    vp_ot_s,
    ob.start_cp,
    vp_ob_s,
    ot.cps_pos[0],
    ob.cps_pos[0],
  )
  let s_top_e = smooth_line_edge(
    ctx,
    it.end_cp,
    vp_it_e,
    ot.end_cp,
    vp_ot_e,
    it.cps_pos[it.cps_pos.length() - 1],
    ot.cps_pos[ot.cps_pos.length() - 1],
  )
  let s_bot_e = smooth_line_edge(
    ctx,
    ib.end_cp,
    vp_ib_e,
    ob.end_cp,
    vp_ob_e,
    ib.cps_pos[ib.cps_pos.length() - 1],
    ob.cps_pos[ob.cps_pos.length() - 1],
  )
  let s_it_e = smooth_line_edge(
    ctx,
    it.end_cp,
    vp_it_e,
    ib.end_cp,
    vp_ib_e,
    it.cps_pos[it.cps_pos.length() - 1],
    ib.cps_pos[ib.cps_pos.length() - 1],
  )
  let s_ot_e = smooth_line_edge(
    ctx,
    ot.end_cp,
    vp_ot_e,
    ob.end_cp,
    vp_ob_e,
    ot.cps_pos[ot.cps_pos.length() - 1],
    ob.cps_pos[ob.cps_pos.length() - 1],
  )

  // Outward directions at the start, in world coordinates.
  let start_radial_local = v_norm((path.points[0].0, path.points[0].1, 0.0))
  let start_tangent_local = v_norm(path.tangents[0])
  let end_tangent_local = v_norm(path.tangents[num_path_pts - 1])
  let top_out = v_norm(xform.apply_dir((0.0, 0.0, 1.0)))
  let bottom_out = v_norm(xform.apply_dir((0.0, 0.0, -1.0)))
  let inner_out = v_norm(xform.apply_dir(v_scale(start_radial_local, -1.0)))
  let outer_out = v_norm(xform.apply_dir(start_radial_local))
  let start_out = v_norm(xform.apply_dir(v_scale(start_tangent_local, -1.0)))
  let end_out = v_norm(xform.apply_dir(end_tangent_local))

  let (top_surf, top_same) = smooth_surface(
    ctx, it, ot, top_out, v_mults, v_knots,
  )
  let (bottom_surf, bottom_same) = smooth_surface(
    ctx, ib, ob, bottom_out, v_mults, v_knots,
  )
  let (inner_surf, inner_same) = smooth_surface(
    ctx, it, ib, inner_out, v_mults, v_knots,
  )
  let (outer_surf, outer_same) = smooth_surface(
    ctx, ot, ob, outer_out, v_mults, v_knots,
  )

  let start_location = xform.apply(path.points[0])
  let end_location = xform.apply(path.points[num_path_pts - 1])
  let (
    start_axis,
    start_center,
    start_ref_dir,
    end_axis,
    end_center,
    end_ref_dir,
  ) = match s.corner_override {
    Some(_) => {
      let last = it.cps_pos.length() - 1
      let s_cycle = [it.cps_pos[0], ot.cps_pos[0], ob.cps_pos[0], ib.cps_pos[0]]
      let e_cycle = [
        it.cps_pos[last],
        ot.cps_pos[last],
        ob.cps_pos[last],
        ib.cps_pos[last],
      ]
      let s_center = smooth_average(s_cycle)
      let e_center = smooth_average(e_cycle)
      let mut s_axis = smooth_polygon_normal(s_cycle)
      if v_dot(s_axis, v_sub(e_center, s_center)) < 0.0 {
        s_axis = v_scale(s_axis, -1.0)
      }
      let mut e_axis = smooth_polygon_normal(e_cycle)
      if v_dot(e_axis, v_sub(s_center, e_center)) < 0.0 {
        e_axis = v_scale(e_axis, -1.0)
      }
      let s_ref = v_norm(v_sub(s_cycle[1], s_cycle[0]))
      let e_ref = v_norm(v_sub(e_cycle[1], e_cycle[0]))
      (s_axis, s_center, s_ref, e_axis, e_center, e_ref)
    }
    None =>
      (
        start_out,
        start_location,
        xform.apply_dir(start_radial_local),
        end_out,
        end_location,
        xform.apply_dir(start_radial_local),
      )
  }
  let start_plane = smooth_cap_plane(
    ctx, start_axis, start_center, start_ref_dir,
  )
  let end_plane = smooth_cap_plane(ctx, end_axis, end_center, end_ref_dir)

  let flip = fn(same : Bool) -> Bool { if reverse { !same } else { same } }

  let faces : Array[@step.Ref] = []
  // Top: start radial, outer helix forward, end radial reversed, inner
  // helix reversed.
  faces.push(
    smooth_face(
      ctx,
      [(s_top_s, true), (he_ot, true), (s_top_e, false), (he_it, false)],
      top_surf,
      flip(top_same),
    ),
  )
  // Bottom.
  faces.push(
    smooth_face(
      ctx,
      [(he_ib, true), (s_bot_e, true), (he_ob, false), (s_bot_s, false)],
      bottom_surf,
      flip(bottom_same),
    ),
  )
  // Inner.
  faces.push(
    smooth_face(
      ctx,
      [(he_it, true), (s_it_e, true), (he_ib, false), (s_it_s, false)],
      inner_surf,
      flip(inner_same),
    ),
  )
  // Outer.
  faces.push(
    smooth_face(
      ctx,
      [(s_ot_s, true), (he_ob, true), (s_ot_e, false), (he_ot, false)],
      outer_surf,
      flip(outer_same),
    ),
  )
  // Start cap (outward opposite the path tangent).
  faces.push(
    smooth_face(
      ctx,
      [(s_it_s, true), (s_bot_s, true), (s_ot_s, false), (s_top_s, false)],
      start_plane,
      flip(true),
    ),
  )
  // End cap (outward along the path tangent).
  faces.push(
    smooth_face(
      ctx,
      [(s_top_e, true), (s_ot_e, true), (s_bot_e, false), (s_it_e, false)],
      end_plane,
      flip(true),
    ),
  )
  faces
}
