///|
fn an_conical_mesh(e : ConicalExtrusion) -> (Array[Vec3], Array[Array[Int32]]) {
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let h = e.height_mm
  let d = e.apex_distance_mm
  if h <= 0.0 || d <= h {
    return (verts, faces)
  }
  let k = (d - h) / d
  let loops : Array[Array[Vec2]] = [
    e.profile.outer,
    ..e.profile.holes.filter(fn(hh) { hh.length() >= 3 }),
  ]
  for lp in loops {
    let n = lp.length()
    if n < 3 {
      continue
    }
    let base = verts.length()
    for p in lp {
      verts.push((p.0, p.1, 0.0))
    }
    for p in lp {
      verts.push((k * p.0, k * p.1, h))
    }
    for i in 0..<n {
      let j = (i + 1) % n
      faces.push([base + i, base + j, base + n + j, base + n + i])
    }
    for i in 1..<(n - 1) {
      faces.push([base, base + i + 1, base + i])
      faces.push([base + n, base + n + i, base + n + i + 1])
    }
  }
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let kseg = 32
      let base = verts.length()
      for i in 0..<kseg {
        let th = 2.0 * @math.PI * i.to_double() / kseg.to_double()
        let x = center.0 + rb * @math.cos(th)
        let y = center.1 + rb * @math.sin(th)
        verts.push((x, y, 0.0))
        verts.push((x, y, h))
      }
      for i in 0..<kseg {
        let j = (i + 1) % kseg
        faces.push([
          base + 2 * i,
          base + 2 * j,
          base + 2 * j + 1,
          base + 2 * i + 1,
        ])
      }
    }
    None => ()
  }
  (verts, faces)
}

///|
fn an_bezier_group_is_curved(group : Array[BezierPath]) -> Bool {
  for path in group {
    if path_has_curved_span(path) {
      return true
    }
  }
  false
}

///|
fn an_bezier_contour_ok(path : BezierPath) -> Bool {
  bspline_control_points(path).length() >= 4
}

///|
fn an_bezier_inventory(e : ExtrudedBezierProfile) -> SurfaceInventory {
  let mut planes = 0
  let mut swept = 0
  if e.height_mm == 0.0 {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  for group in bezier_path_groups(e.paths) {
    if group.is_empty() {
      continue
    }
    if an_bezier_group_is_curved(group) {
      if !an_bezier_contour_ok(group[0]) {
        continue
      }
      planes = planes + 2
      swept = swept + 1
      for i in 1..<group.length() {
        if an_bezier_contour_ok(group[i]) {
          swept = swept + 1
        }
      }
    } else {
      let profile = flatten_group_profile(group)
      if profile.outer.length() < 3 {
        continue
      }
      planes = planes + 2 + profile.outer.length()
      for h in profile.holes {
        if h.length() >= 3 {
          planes = planes + h.length()
        }
      }
    }
  }
  an_inventory(planes, 0, 0, 0, 0, 0, swept, 0)
}

///|
/// an_swept_inventory mirrors the swept-profile compiler's planar triangulation.
fn an_swept_inventory(s : SweptProfile) -> SurfaceInventory {
  let path = s.path
  let profile = s.profile
  let num_path_pts = path.points.length()
  if num_path_pts < 2 || profile.vertices.length() < 3 {
    return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  let loops : Array[Array[Vec3]] = [
    profile.vertices,
    ..profile.holes.filter(fn(h) { h.length() >= 3 }),
  ]
  let prof_z = v_norm(profile.normal_dir)
  let prof_x = v_norm(profile.right_dir)
  let prof_y = v_cross(prof_z, prof_x)
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
  let local_loops = loops.map(fn(lp) {
    lp.map(fn(v) { apply_matrix(m_global_to_prof, v_sub(v, profile.center)) })
  })
  let local_verts : Array[Vec3] = []
  let is_hole : Array[Bool] = []
  let loop_offsets : Array[Int32] = []
  let mut loop_index = 0
  for lp in local_loops {
    loop_offsets.push(local_verts.length())
    for v in lp {
      local_verts.push(v)
      is_hole.push(loop_index > 0)
    }
    loop_index = loop_index + 1
  }
  let t0 = v_norm(path.tangents[0])
  let n0 = v_norm(path.normals[0])
  let r0 = v_norm(v_cross(t0, n0))
  let m_start_to_global = Matrix3x3::{
    m00: r0.0,
    m01: n0.0,
    m02: t0.0,
    m10: r0.1,
    m11: n0.1,
    m12: t0.1,
    m20: r0.2,
    m21: n0.2,
    m22: t0.2,
  }
  let pts : Array[Vec3] = []
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
      let keep_straight = if is_hole[j] {
        s.straight_holes
      } else {
        s.straight_outline
      }
      let gv = if keep_straight {
        apply_matrix(m_start_to_global, v)
      } else {
        apply_matrix(m_path_to_global, v)
      }
      pts.push((gv.0 + p_origin.0, gv.1 + p_origin.1, gv.2 + p_origin.2))
    }
  }
  let num_prof_verts = local_verts.length()
  let mut planes = 0
  for i in 0..<(num_path_pts - 1) {
    let offset1 = i * num_prof_verts
    let offset2 = (i + 1) * num_prof_verts
    for li in 0..<local_loops.length() {
      let lo = loop_offsets[li]
      let n = local_loops[li].length()
      for j in 0..<n {
        let k = (j + 1) % n
        let b1 = offset1 + lo + j
        let b2 = offset1 + lo + k
        let t1 = offset2 + lo + j
        let t2 = offset2 + lo + k
        let p0 = pts[b1]
        let p1 = pts[b2]
        let p2 = pts[t1]
        let p3 = pts[t2]
        let expected = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
        let off = Double::abs(v_dot(v_sub(p3, p0), expected))
        if off <= @step.TOL_1E6 {
          planes = planes + 1
        } else {
          planes = planes + 2
        }
      }
    }
  }
  if s.make_start_cap {
    planes = planes + 1
  }
  if s.make_end_cap {
    planes = planes + 1
  }
  an_inventory(planes, 0, 0, 0, 0, 0, 0, 0)
}

///|
/// an_bevel_smooth_bsplines counts the smooth B-spline faces the smooth
/// compiler emits: three side strips and three tooth-end cap strips per tooth
/// (two strips when the tip is a single point), plus one gap root land.
fn an_bevel_smooth_bsplines(b : BevelGearBody) -> Int32 {
  let n = b.back.length()
  let mut total = 0
  for k, tooth in b.teeth {
    let (start, end) = tooth
    if start < 0 || end >= n || end <= start {
      continue
    }
    let count = end - start + 1
    let points : Array[Vec3] = []
    for i in start..<=end {
      points.push(b.back[i])
    }
    let corners = if k < b.tips.length() {
      let (tip_start, tip_end) = b.tips[k]
      [tip_start - start, tip_end - start]
    } else {
      bevel_smooth_tip_corners(points)
    }
    let mut segments = 1
    let mut last = 0
    for corner in corners {
      if corner > last && corner < count - 1 {
        segments = segments + 1
        last = corner
      }
    }
    // One side surface per strip plus one gap root land; with the explicit end
    // chamfer each strip also gets a chamfer-band surface.
    let per_strip = if b.chamfer_mm > 0.0 { 2 } else { 1 }
    total = total + per_strip * (segments + 1)
  }
  total
}

///|
/// an_bevel_lobe_tris counts the conical cap triangles the compiler emits.
fn an_bevel_lobe_tris(b : BevelGearBody) -> Int32 {
  let n = b.back.length()
  if n < 3 || b.teeth.is_empty() {
    return 0
  }
  let (start0, _) = b.teeth[0]
  if start0 < 0 || start0 >= n {
    return 0
  }
  let root_radius = Double::sqrt(
    b.back[start0].0 * b.back[start0].0 + b.back[start0].1 * b.back[start0].1,
  )
  let two_pi = 2.0 * @math.PI
  let mut count_tris = 0
  for tooth in b.teeth {
    let (start, end) = tooth
    let count = end - start + 1
    if count < 2 {
      continue
    }
    let a0 = @math.atan2(b.back[start].1, b.back[start].0)
    let a1 = @math.atan2(b.back[end].1, b.back[end].0)
    let raw = a1 - a0
    let mut delta = raw - two_pi * Double::floor(raw / two_pi)
    if delta <= @step.TOL_1E12 {
      delta = delta + two_pi
    }
    let arc : Array[Vec3] = [b.back[start]]
    for i in 1..<(count - 1) {
      let ang = a0 + delta * i.to_double() / (count - 1).to_double()
      arc.push(
        (
          root_radius * @math.cos(ang),
          root_radius * @math.sin(ang),
          b.root_z_mm,
        ),
      )
    }
    arc.push(b.back[end])
    for i in 0..<(count - 1) {
      let b0 = b.back[start + i]
      let b1 = b.back[start + i + 1]
      let r0 = arc[i]
      let r1 = arc[i + 1]
      let a1v = v_cross(v_sub(b1, b0), v_sub(r1, b0))
      if v_dot(a1v, a1v) > @step.TOL_1E24 {
        count_tris = count_tris + 1
      }
      let a2v = v_cross(v_sub(r1, b0), v_sub(r0, b0))
      if v_dot(a2v, a2v) > @step.TOL_1E24 {
        count_tris = count_tris + 1
      }
    }
  }
  count_tris
}

///|
/// an_shape_inventory mirrors the compiler's face-emission rules.
fn an_shape_inventory(shape : Shape) -> SurfaceInventory {
  match shape {
    Cuboid(_) => an_inventory(6, 0, 0, 0, 0, 0, 0, 0)
    Cylinder(c) =>
      if c.diameter / 2.0 > 0.0 && c.height > 0.0 {
        an_inventory(2, 1, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    ToroidalBend(b) =>
      if !b.validate() {
        an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      } else if b.inner_diameter_mm > CAD_LENGTH_EPS {
        an_inventory(2, 0, 0, 0, 2, 0, 0, 0)
      } else {
        an_inventory(2, 0, 0, 0, 1, 0, 0, 0)
      }
    PipeJunction(j) =>
      match junction_port_mask(j.ports) {
        None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
        Some(mask) =>
          if !j.validate() {
            an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
          } else {
            let np = j.ports.length()
            let mut n_sph = 0
            for sx in [0, 1] {
              for sy in [2, 3] {
                for sz in [4, 5] {
                  if !mask[sx] && !mask[sy] && !mask[sz] {
                    n_sph = n_sph + 1
                  }
                }
              }
            }
            let cones = if j.mouth_chamfer_mm > 0.0 { np * 8 } else { 0 }
            an_inventory(np * 8, np * 12, cones, n_sph * 2, 0, 0, 0, 0)
          }
      }
    RevolvedProfile(rev) => {
      match rev.validate() {
        Err(_) => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
        Ok(_) => ()
      }
      let mut p = 0
      let mut cy = 0
      let mut co = 0
      let mut sp = 0
      let mut to = 0
      for seg in rev.segments {
        let (a, b, center) = match seg {
          RevLine(a, b) => (a, b, None)
          RevArc(a, b, c) => (a, b, Some(c))
        }
        let has_a = a.0 > CAD_LENGTH_EPS
        let has_b = b.0 > CAD_LENGTH_EPS
        if !(has_a || has_b) {
          // A pole-to-pole band is a full sphere (or a degenerate line band
          // with no area).
          match center {
            Some(c) =>
              if c.0.abs() < CAD_LENGTH_EPS {
                sp = sp + 1
              } else {
                to = to + 1
              }
            None => ()
          }
          continue
        }
        match center {
          Some(c) =>
            if c.0.abs() < CAD_LENGTH_EPS {
              sp = sp + 1
            } else {
              to = to + 1
            }
          None => {
            let radial = (a.1 - b.1).abs() < CAD_LENGTH_EPS
            let axial = (a.0 - b.0).abs() < CAD_LENGTH_EPS
            if radial {
              p = p + 1
            } else if axial {
              cy = cy + 1
            } else {
              co = co + 1
            }
          }
        }
      }
      an_inventory(p, cy, co, sp, to, 0, 0, 0)
    }
    ChamferedPrism(p) => an_prism_inventory(p)
    SocketedSolid(s) => an_socketed_inventory(s)
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let lead_cones = if g.lead > 0.0 { 2 } else { 0 }
          an_inventory(8, 1, 12 + lead_cones, 0, 0, 0, 0, 0)
        }
        None => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    SlitTube(t) => an_slit_tube_inventory(t)
    AcornNut(n) => an_acorn_nut_inventory(n)
    SquareNut(n) => an_square_nut_inventory(n)
    CalibrationChamferBlock(b) => {
      let rings = an_calib_rings(b)
      let n = rings.length()
      if n >= 2 {
        an_inventory(2 + 4 * (n - 1), 0, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
    }
    ExtrudedProfile(e) => {
      if e.height_mm == 0.0 || e.profile.outer.length() < 3 {
        return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
      let outer_n = e.profile.outer.length()
      let mut hole_n = 0
      for h in e.profile.holes {
        if h.length() >= 3 {
          hole_n = hole_n + h.length()
        }
      }
      let cylinder = match e.round_bore {
        Some((_center, diameter)) => if diameter > 0.0 { 1 } else { 0 }
        None => 0
      }
      an_inventory(2 + outer_n + hole_n, cylinder, 0, 0, 0, 0, 0, 0)
    }
    ConicalExtrusion(e) => {
      if e.height_mm <= 0.0 ||
        e.apex_distance_mm <= e.height_mm ||
        e.profile.outer.length() < 3 {
        return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
      let outer_n = e.profile.outer.length()
      let mut hole_n = 0
      for h in e.profile.holes {
        if h.length() >= 3 {
          hole_n = hole_n + h.length()
        }
      }
      let cylinder = match e.round_bore {
        Some((_center, diameter)) => if diameter > 0.0 { 1 } else { 0 }
        None => 0
      }
      an_inventory(2 + outer_n + hole_n, cylinder, 0, 0, 0, 0, 0, 0)
    }
    BevelGearBody(b) => {
      if b.back.length() < 3 ||
        b.front.length() != b.back.length() ||
        b.teeth.is_empty() {
        return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      }
      if b.smooth {
        // Two planar caps, one analytic bore, one trimmed back-cone face per
        // tooth, and the side strips plus gap lands.
        return an_inventory(
          2,
          if b.bore_radius_mm > 0.0 {
            1
          } else {
            0
          },
          b.teeth.length(),
          0,
          0,
          an_bevel_smooth_bsplines(b),
          0,
          0,
        )
      }
      an_inventory(
        2 * b.back.length() + an_bevel_lobe_tris(b) + 2,
        if b.bore_radius_mm > 0.0 {
          1
        } else {
          0
        },
        0,
        0,
        0,
        0,
        0,
        0,
      )
    }
    ExtrudedArcProfile(e) => an_extruded_arc_inventory(e)
    SquareHoleWasher(w) => an_square_hole_inventory(w)
    TabWasher(w) => an_tab_inventory(w)
    // Six planar flats, the flat underside, and the circular top: eight planes.
    // The chamfer is six CONICAL_SURFACE patches, not cylinders. The unified
    // shank variant adds the underside annulus, washer face, tip disk and
    // shank/land cylinders.
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let washer = h.washer_face_diameter_mm > 0.0 &&
          h.washer_face_height_mm > 0.0
        let tip_cone = h.tip_chamfer_mm > 0.0 &&
          h.tip_chamfer_mm < h.shank_diameter_mm / 2.0
        an_inventory(
          9 + (if washer { 1 } else { 0 }),
          1 + (if washer { 1 } else { 0 }),
          6 + (if tip_cone { 1 } else { 0 }),
          0,
          0,
          0,
          0,
          0,
        )
      } else {
        an_inventory(8, 0, 6, 0, 0, 0, 0, 0)
      }
    ExtrudedBezierProfile(e) => an_bezier_inventory(e)
    SweptProfile(s) => an_swept_inventory(s)
    Fillet(f) => an_shape_inventory(f.base.shape)
    Chamfer(c) => an_shape_inventory(c.base.shape)
    Union(u) => {
      let mut inv = an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
      for child in u.nodes {
        inv = inv.add(an_shape_inventory(child.shape))
      }
      inv
    }
    Difference(d) => {
      let mut inv = an_shape_inventory(d.base.shape)
      for cutter in d.cutters {
        inv = inv.add(an_shape_inventory(cutter.shape))
      }
      inv
    }
    ImportedStep(_) => an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
}

///|
fn an_prism_inventory(p : ChamferedPrism) -> SurfaceInventory {
  match p.validate() {
    Err(_) => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
    Ok(_) => ()
  }
  let nc = p.base.length()
  let nl = p.levels.length()
  match p.round_bore {
    Some((_center, diameter)) =>
      if diameter > 0.0 {
        an_inventory(2 + (nl - 1) * nc, 1, 0, 0, 0, 0, 0, 0)
      } else {
        an_inventory(2 + (nl - 1) * nc, 0, 0, 0, 0, 0, 0, 0)
      }
    None => {
      let mut planes = 2 + (nl - 1) * nc
      match p.hole {
        Some(h) =>
          match p.hole_levels {
            Some(hls) => planes = planes + (hls.length() - 1) * h.length()
            None => planes = planes + h.length()
          }
        None => ()
      }
      an_inventory(planes, 0, 0, 0, 0, 0, 0, 0)
    }
  }
}

///|
/// an_socketed_inventory mirrors the `compile_socketed_solid` face emission: the
/// body's analytic revolve faces minus its flat top cap, plus the annular top
/// face, six socket walls, the optional six ruled lead-in faces, and the floor.
fn an_socketed_inventory(s : SocketedSolid) -> SurfaceInventory {
  let base = an_shape_inventory(Shape::RevolvedProfile(s.body))
  if s.conical {
    // The top cap is replaced by the annular top face and six flat planes; the
    // rim and drill cones are one surface entity each (shared by their
    // patches), giving the detailed reference's plane 9 / cone 5 / cylinder 2.
    return an_inventory(
      base.plane - 1 + 7,
      base.cylinder,
      base.cone + 2,
      base.sphere,
      base.torus,
      base.bspline,
      base.swept,
      base.other,
    )
  }
  let g = match socketed_geometry(s) {
    Some(v) => v
    None => return an_inventory(0, 0, 0, 0, 0, 0, 0, 0)
  }
  let lead_faces = if g.lead > CAD_DEGENERATE_EPS { 6 } else { 0 }
  an_inventory(
    base.plane - 1 + 8 + lead_faces,
    base.cylinder,
    base.cone,
    base.sphere,
    base.torus,
    base.bspline,
    base.swept,
    base.other,
  )
}

///|
/// Shape::surface_inventory returns the analytic face counts the compiler
/// emits for this shape.
pub fn Shape::surface_inventory(self : Shape) -> SurfaceInventory {
  an_shape_inventory(self)
}

///|
/// Shape::analysis_volume returns the exact volume in mm^3, or a typed error
/// when the shape is not analytically analyzable.
pub fn Shape::analysis_volume(self : Shape) -> Result[Double, AnalysisError] {
  match self {
    Cuboid(c) => Ok(c.sx * c.sy * c.sz)
    Cylinder(c) =>
      Ok(@math.PI * (c.diameter / 2.0) * (c.diameter / 2.0) * c.height)
    RevolvedProfile(rev) => {
      let (volume, _zc) = an_rev_volume_centroid(rev)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ToroidalBend(b) => {
      let volume = b.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    PipeJunction(j) => {
      let volume = j.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ChamferedPrism(p) => {
      let (volume, _c) = an_prism_volume_centroid(p)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    SocketedSolid(s) => {
      let volume = s.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let (volume, _zc) = conical_nut_volume_centroid(g)
          if volume <= 0.0 {
            Err(DegenerateProfile)
          } else {
            Ok(volume)
          }
        }
        None => Err(DegenerateProfile)
      }
    SlitTube(t) => {
      let volume = t.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    AcornNut(n) => {
      let volume = n.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    SquareNut(n) => {
      let volume = n.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    CalibrationChamferBlock(b) => {
      let (volume, _c) = an_calib_volume_centroid(b)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ExtrudedProfile(e) => {
      let (volume, _c) = an_extruded_volume_centroid(e)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    ConicalExtrusion(e) => {
      let (volume, _c) = an_conical_volume_centroid(e)
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    BevelGearBody(_) =>
      Err(NotAnalytic("back-cone bevel body requires tessellation"))
    ExtrudedArcProfile(e) => {
      let volume = e.volume()
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    SquareHoleWasher(w) => {
      let volume = shw_area(w) * w.thickness_mm
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    TabWasher(w) => {
      let (material, _c) = tw_area_centroid(w)
      let volume = material * w.thickness_mm
      if volume <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(volume)
      }
    }
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let (volume, _c) = hhwf_screw_volume_centroid(h)
        if volume <= 0.0 {
          Err(DegenerateProfile)
        } else {
          Ok(volume)
        }
      } else {
        match hhwf_proxy(h) {
          Some(p) => {
            let volume = p.volume()
            if volume <= 0.0 {
              Err(DegenerateProfile)
            } else {
              Ok(volume)
            }
          }
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(u) => {
      let mut volume = 0.0
      for child in u.nodes {
        match child.shape.analysis_volume() {
          Ok(v) => volume = volume + v
          Err(e) => return Err(e)
        }
      }
      Ok(volume)
    }
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
    ImportedStep(_) =>
      Err(NotAnalytic("imported STEP volume is not analyzed by the DSL"))
  }
}

///|
/// Shape::analysis_centroid returns the exact centroid in the shape's local
/// frame, or a typed error when it is not analytically known.
pub fn Shape::analysis_centroid(self : Shape) -> Result[Vec3, AnalysisError] {
  match self {
    Cuboid(c) => Ok((c.sx / 2.0, c.sy / 2.0, c.sz / 2.0))
    Cylinder(c) => Ok((0.0, 0.0, c.height / 2.0))
    RevolvedProfile(rev) => {
      let (_volume, zc) = an_rev_volume_centroid(rev)
      Ok((0.0, 0.0, zc))
    }
    ToroidalBend(b) =>
      if !b.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(b.centroid())
      }
    PipeJunction(j) =>
      if !j.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(j.centroid())
      }
    ChamferedPrism(p) => {
      let (_volume, c) = an_prism_volume_centroid(p)
      Ok(c)
    }
    SocketedSolid(s) => Ok(s.centroid())
    ConicalNut(n) =>
      match conical_nut_geometry(n) {
        Some(g) => {
          let (_volume, zc) = conical_nut_volume_centroid(g)
          Ok((0.0, 0.0, zc))
        }
        None => Err(DegenerateProfile)
      }
    SlitTube(t) => Ok(t.centroid())
    AcornNut(n) => Ok(n.centroid())
    SquareNut(n) => Ok(n.centroid())
    CalibrationChamferBlock(b) => {
      let (_volume, c) = an_calib_volume_centroid(b)
      Ok(c)
    }
    ExtrudedProfile(e) => {
      let (_volume, c) = an_extruded_volume_centroid(e)
      Ok(c)
    }
    ConicalExtrusion(e) => {
      let (_volume, c) = an_conical_volume_centroid(e)
      Ok(c)
    }
    BevelGearBody(_) =>
      Err(NotAnalytic("back-cone bevel body requires tessellation"))
    ExtrudedArcProfile(e) => Ok(e.centroid())
    SquareHoleWasher(w) => Ok((0.0, 0.0, w.thickness_mm / 2.0))
    TabWasher(w) => {
      let (_material, c) = tw_area_centroid(w)
      Ok((c.0, c.1, w.thickness_mm / 2.0))
    }
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let (_volume, zc) = hhwf_screw_volume_centroid(h)
        Ok((0.0, 0.0, zc))
      } else {
        match hhwf_proxy(h) {
          Some(p) => {
            let (_volume, c) = an_prism_volume_centroid(p)
            Ok(c)
          }
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(u) => {
      let mut volume = 0.0
      let mut mx = 0.0
      let mut my = 0.0
      let mut mz = 0.0
      for child in u.nodes {
        let v = match child.shape.analysis_volume() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let c = match child.shape.analysis_centroid() {
          Ok(c) => c
          Err(e) => return Err(e)
        }
        let (rx, ry, rz) = rotate_point(c, child.rx, child.ry, child.rz)
        volume = volume + v
        mx = mx + v * (rx + child.tx)
        my = my + v * (ry + child.ty)
        mz = mz + v * (rz + child.tz)
      }
      if volume <= @step.TOL_1E12 {
        Err(DegenerateProfile)
      } else {
        Ok((mx / volume, my / volume, mz / volume))
      }
    }
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
    ImportedStep(_) =>
      Err(NotAnalytic("imported STEP centroid is not analyzed by the DSL"))
  }
}

///|
/// Shape::section_at_local returns the exact horizontal cross-section at local
/// `z`.
pub fn Shape::section_at_local(
  self : Shape,
  z : Double,
) -> Result[Section, AnalysisError] {
  match self {
    Cuboid(c) => {
      if z < -CAD_LENGTH_EPS || z > c.sz + CAD_LENGTH_EPS {
        return Err(EmptySection)
      }
      let area = c.sx * c.sy
      if area <= @step.TOL_1E12 {
        return Err(DegenerateProfile)
      }
      let outer = Double::sqrt(c.sx * c.sx + c.sy * c.sy)
      Ok({
        z_mm: z,
        area_mm2: area,
        perimeter_mm: 2.0 * (c.sx + c.sy),
        outer_radius_mm: outer,
        inner_radius_mm: 0.0,
        rings: [{ inner_radius_mm: 0.0, outer_radius_mm: outer, }],
      })
    }
    Cylinder(c) => Cylinder::section_at(c, z)
    RevolvedProfile(rev) => rev.section_at(z)
    ToroidalBend(_) =>
      Err(NotAnalytic("toroidal bend section at arbitrary z is not planar"))
    PipeJunction(_) =>
      Err(
        NotAnalytic("multi-port junction section at arbitrary z is not planar"),
      )
    ChamferedPrism(p) => p.section_at(z)
    SocketedSolid(s) => an_socketed_section(s, z)
    ConicalNut(n) => an_conical_nut_section(n, z)
    AcornNut(n) => an_acorn_nut_section(n, z)
    SquareNut(n) => an_square_nut_section(n, z)
    SlitTube(t) => an_slit_tube_section(t, z)
    CalibrationChamferBlock(b) => an_calib_section(b, z)
    ExtrudedProfile(e) => e.section_at(z)
    ConicalExtrusion(e) => an_conical_section(e, z)
    BevelGearBody(_) =>
      Err(NotAnalytic("back-cone bevel body requires tessellation"))
    ExtrudedArcProfile(e) => an_extruded_arc_section(e, z)
    SquareHoleWasher(w) => an_square_hole_section(w, z)
    TabWasher(w) => an_tab_section(w, z)
    HexHeadWasherFace(h) =>
      if hhwf_screw_has_shank(h) {
        let area = hhwf_screw_area(h, z)
        if area <= CAD_AREA_EPS {
          Err(EmptySection)
        } else {
          let outer = Double::sqrt(area / @math.PI)
          Ok({
            z_mm: z,
            area_mm2: area,
            perimeter_mm: hhwf_screw_perimeter(h, z),
            outer_radius_mm: outer,
            inner_radius_mm: 0.0,
            rings: [{ inner_radius_mm: 0.0, outer_radius_mm: outer, }],
          })
        }
      } else {
        match hhwf_proxy(h) {
          Some(p) => p.section_at(z)
          None => Err(DegenerateProfile)
        }
      }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("Bezier profile requires tessellation"))
    SweptProfile(_) => Err(NotAnalytic("swept profile requires tessellation"))
    Fillet(_) => Err(NotAnalytic("edge fillet requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("edge chamfer requires a trimming kernel"))
    Union(_) => Err(NotAnalytic("union sections are reported per child"))
    ImportedStep(_) =>
      Err(NotAnalytic("imported STEP sections are not analyzed by the DSL"))
    Difference(_) =>
      Err(NotAnalytic("nominal difference is not a trimmed solid"))
  }
}

///|
/// Cylinder::section_at returns the exact disc section at local `z`.
pub fn Cylinder::section_at(
  self : Cylinder,
  z : Double,
) -> Result[Section, AnalysisError] {
  let r = self.diameter / 2.0
  if r <= 0.0 || self.height <= 0.0 {
    return Err(DegenerateProfile)
  }
  if z < -CAD_LENGTH_EPS || z > self.height + CAD_LENGTH_EPS {
    return Err(EmptySection)
  }
  Ok({
    z_mm: z,
    area_mm2: @math.PI * r * r,
    perimeter_mm: 2.0 * @math.PI * r,
    outer_radius_mm: r,
    inner_radius_mm: 0.0,
    rings: [{ inner_radius_mm: 0.0, outer_radius_mm: r, }],
  })
}

///|
/// Cylinder::volume returns the exact cylinder volume.
pub fn Cylinder::volume(self : Cylinder) -> Double {
  let r = self.diameter / 2.0
  @math.PI * r * r * self.height
}

///|
/// RevolvedProfile::section_at returns the exact section at local `z`.
pub fn RevolvedProfile::section_at(
  self : RevolvedProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_rev_section(self, z)
}

///|
/// RevolvedProfile::volume returns the exact volume.
pub fn RevolvedProfile::volume(self : RevolvedProfile) -> Double {
  let (volume, _zc) = an_rev_volume_centroid(self)
  volume
}

///|
/// RevolvedProfile::centroid returns the exact centroid.
pub fn RevolvedProfile::centroid(self : RevolvedProfile) -> Vec3 {
  let (_volume, zc) = an_rev_volume_centroid(self)
  (0.0, 0.0, zc)
}

///|
/// ExtrudedProfile::section_at returns the exact extruded section at local
/// `z`.
pub fn ExtrudedProfile::section_at(
  self : ExtrudedProfile,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_extruded_section(self, z)
}

///|
/// ExtrudedProfile::volume returns the exact extruded volume.
pub fn ExtrudedProfile::volume(self : ExtrudedProfile) -> Double {
  let (volume, _c) = an_extruded_volume_centroid(self)
  volume
}

///|
/// ConicalExtrusion::section_at returns the exact tapered section at local
/// `z`.
pub fn ConicalExtrusion::section_at(
  self : ConicalExtrusion,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_conical_section(self, z)
}

///|
/// ConicalExtrusion::volume returns the exact tapered volume.
pub fn ConicalExtrusion::volume(self : ConicalExtrusion) -> Double {
  let (volume, _c) = an_conical_volume_centroid(self)
  volume
}

///|
/// ChamferedPrism::section_at returns the exact prism section at local `z`.
pub fn ChamferedPrism::section_at(
  self : ChamferedPrism,
  z : Double,
) -> Result[Section, AnalysisError] {
  an_prism_section(self, z)
}

///|
/// ChamferedPrism::volume returns the exact prism volume.
pub fn ChamferedPrism::volume(self : ChamferedPrism) -> Double {
  let (volume, _c) = an_prism_volume_centroid(self)
  volume
}
