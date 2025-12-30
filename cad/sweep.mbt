///|
/// SweptProfile::new generates a new Shape by sweeping a 2D profile along a 3D path.
/// Note that the resulting Shape has no end caps; both ends are open.
pub fn SweptProfile::new(
  path~ : SweepPath,
  profile~ : SweepProfile,
  make_start_cap? : Bool = true,
  make_end_cap? : Bool = true,
) -> Shape {
  Shape::SweptProfile({ path, profile, make_start_cap, make_end_cap })
}

///|
fn compile_swept_profile(
  ctx : StepContext,
  node : SceneNode,
  s : SweptProfile,
) -> @step.Ref {
  let path = s.path
  let profile = s.profile
  if path.points.length() < 2 || profile.vertices.length() < 3 {
    return { id: { value: 0 } }
  }
  let num_path_pts = path.points.length()
  let num_prof_verts = profile.vertices.length()

  // 1. Calculate profile-local to global (centered at origin)
  let prof_z = v_norm(profile.normal_dir)
  let prof_x = v_norm(profile.right_dir)
  let prof_y = v_norm(v_cross(prof_z, prof_x))

  // global to profile-local (centered at origin)
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

  // Vertices in profile-local coordinate system (relative to profile.center)
  let local_verts = profile.vertices.map(fn(v) {
    apply_matrix(m_global_to_prof, v_sub(v, profile.center))
  })

  // 2. Transform local_verts to each path point.
  let pts_raw : Array[Vec3] = []
  for i in 0..<num_path_pts {
    let p_origin = path.points[i]
    let p_tangent = v_norm(path.tangents[i])
    let p_normal = v_norm(path.normals[i])
    let p_right = v_norm(v_cross(p_tangent, p_normal))

    // Path-point-local to global:
    // Z = tangent, Y = normal, X = right
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
    for v in local_verts {
      let gv = apply_matrix(m_path_to_global, v)
      pts_raw.push((gv.0 + p_origin.0, gv.1 + p_origin.1, gv.2 + p_origin.2))
    }
  }

  // 3. Apply Node transform (Rotate then Translate)
  let pts = pts_raw.map(fn(pt) {
    let (rx, ry, rz) = rotate_point(pt, node.rx, node.ry, node.rz)
    (rx + node.tx, ry + node.ty, rz + node.tz)
  })

  // 4. Create STEP entities
  let cp_refs = pts.map(fn(pt) { ctx.cartesian_point(pt.0, pt.1, pt.2) })
  let vp_refs = cp_refs.map(fn(cp_ref) { ctx.vertex_point(cp_ref) })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map::new()
  let add_edge = fn(a : Int, b : Int) -> Unit {
    let key = if a < b { "\{a}:\{b}" } else { "\{b}:\{a}" }
    if seen.get(key).unwrap_or(false) {
      return
    }
    seen.set(key, true)
    let start = if a < b { a } else { b }
    let end = if a < b { b } else { a }
    let dir_raw = v_norm(v_sub(pts[end], pts[start]))
    let dir_ref = ctx.direction(dir_raw.0, dir_raw.1, dir_raw.2)
    let vec_ref = ctx.vector(dir_ref, 1.0)
    let line_ref = ctx.line(cp_refs[start], vec_ref)
    let ec_ref = ctx.edge_curve(vp_refs[start], vp_refs[end], line_ref, true)
    edges.push(EdgeInfo::{ start, end, edge: ec_ref })
  }

  // Profile edges (at each path point)
  for i in 0..<num_path_pts {
    let offset = i * num_prof_verts
    for j in 0..<num_prof_verts {
      let k = (j + 1) % num_prof_verts
      add_edge(offset + j, offset + k)
    }
  }

  // Longitudinal edges (between consecutive path points)
  for i in 0..<(num_path_pts - 1) {
    let offset1 = i * num_prof_verts
    let offset2 = (i + 1) * num_prof_verts
    for j in 0..<num_prof_verts {
      add_edge(offset1 + j, offset2 + j)
    }
  }

  // 5. Create side faces
  let face_refs : Array[@step.Ref] = []
  for i in 0..<(num_path_pts - 1) {
    let offset1 = i * num_prof_verts
    let offset2 = (i + 1) * num_prof_verts
    for j in 0..<num_prof_verts {
      let k = (j + 1) % num_prof_verts
      let b1 = offset1 + j
      let b2 = offset1 + k
      let t1 = offset2 + j
      let t2 = offset2 + k
      let p0 = pts[b1]
      let p1 = pts[b2]
      let p2 = pts[t1]
      let v1 = v_sub(p1, p0)
      let v2 = v_sub(p2, p0)
      let expected = v_norm(v_cross(v1, v2))
      face_refs.push(
        add_plane_face_oriented(
          ctx,
          edges,
          pts,
          cp_refs,
          [b1, b2, t2, t1],
          expected,
        ),
      )
    }
  }

  // 6. Wrap in shell and model
  let shell = @topology.OpenShell::new("", face_refs)
  let shell_ref = ctx.add(@repository.any_entity_open_shell(shell))
  let model = @topology.ShellBasedSurfaceModel::new("", [shell_ref])
  ctx.add(@repository.any_entity_shell_based_surface_model(model))
}
