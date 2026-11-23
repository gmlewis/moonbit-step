///|
/// PipeJunction represents a smooth, watertight, multi-port orthogonal PVC/pipe
/// fitting (`tee`, `cross`, `3-way corner`, `4-way tee`, `5-way cross`) with:
/// - equal-diameter cylindrical outer barrels meeting along exact 45-degree
///   elliptical miters and (where all three axis directions are absent) a
///   tangent spherical corner of `outer_diameter_mm / 2`,
/// - open internal through-bores (`through_bore_mm`) intersecting cleanly with
///   zero internal obstructions, and
/// - concentric socket bores (`socket_bore_mm`), pipe-stop shoulders at
///   `center_to_seat_mm`, and optional 45-degree mouth chamfers at every port.
#derive(Eq, Debug)
pub struct PipeJunction {
  ports : Array[Vec3]
  outer_diameter_mm : Double
  through_bore_mm : Double
  socket_bore_mm : Double
  center_to_seat_mm : Double
  socket_depth_mm : Double
  mouth_chamfer_mm : Double
}

///|
/// PipeJunction::new constructs an analytic orthogonal multi-port pipe fitting.
pub fn PipeJunction::new(
  ports : Array[Vec3],
  outer_diameter_mm : Double,
  through_bore_mm : Double,
  socket_bore_mm : Double,
  center_to_seat_mm : Double,
  socket_depth_mm : Double,
  mouth_chamfer_mm~ : Double = 0.0,
) -> Shape {
  Shape::PipeJunction({
    ports,
    outer_diameter_mm,
    through_bore_mm,
    socket_bore_mm,
    center_to_seat_mm,
    socket_depth_mm,
    mouth_chamfer_mm,
  })
}

///|
/// Resolve a port vector into `(axis_index 0..2, is_positive)` when it lies on
/// one of the six canonical orthogonal axes.
fn junction_port_slot(v : Vec3) -> (Int32, Bool)? {
  let (x, y, z) = v
  let len = Double::sqrt(x * x + y * y + z * z)
  if len < CAD_LENGTH_EPS {
    return None
  }
  let nx = x / len
  let ny = y / len
  let nz = z / len
  if nx.abs() > 1.0 - 1.0e-6 && ny.abs() < 1.0e-6 && nz.abs() < 1.0e-6 {
    Some((0, nx > 0.0))
  } else if ny.abs() > 1.0 - 1.0e-6 && nx.abs() < 1.0e-6 && nz.abs() < 1.0e-6 {
    Some((1, ny > 0.0))
  } else if nz.abs() > 1.0 - 1.0e-6 && nx.abs() < 1.0e-6 && ny.abs() < 1.0e-6 {
    Some((2, nz > 0.0))
  } else {
    None
  }
}

///|
/// Returns the 6-bit orthogonal port mask `[+X, -X, +Y, -Y, +Z, -Z]` or `None`
/// if any port is non-orthogonal or duplicated.
fn junction_port_mask(ports : Array[Vec3]) -> Array[Bool]? {
  if ports.is_empty() {
    return None
  }
  let mask = [false, false, false, false, false, false]
  for p in ports {
    match junction_port_slot(p) {
      None => return None
      Some((axis, is_pos)) => {
        let idx = axis * 2 + (if is_pos { 0 } else { 1 })
        if mask[idx] {
          return None
        }
        mask[idx] = true
      }
    }
  }
  Some(mask)
}

///|
/// PipeJunction::validate checks that all ports are unique orthogonal unit
/// axes and that the radii, lay length, and socket depth produce a valid,
/// non-self-intersecting manifold fitting.
pub fn PipeJunction::validate(self : PipeJunction) -> Bool {
  if junction_port_mask(self.ports) is None {
    return false
  }
  let r_out = self.outer_diameter_mm / 2.0
  let r_flow = self.through_bore_mm / 2.0
  let r_sock = self.socket_bore_mm / 2.0
  let lay = self.center_to_seat_mm
  let c = self.mouth_chamfer_mm
  let z_mouth = lay + self.socket_depth_mm
  r_flow > 1.0e-6 &&
  r_sock > r_flow + 1.0e-6 &&
  r_out > r_sock + 1.0e-6 &&
  lay > r_sock + 1.0e-6 &&
  c >= 0.0 &&
  z_mouth - c > r_out + 1.0e-6 &&
  (
    c == 0.0 ||
    (self.socket_depth_mm > c + 1.0e-6 && r_out - r_sock > 2.0 * c + 1.0e-6)
  )
}

///|
/// PipeJunction::bounding_box returns the exact local axis-aligned bounding
/// box.
pub fn PipeJunction::bounding_box(
  self : PipeJunction,
) -> (Double, Double, Double, Double, Double, Double) {
  let r_out = self.outer_diameter_mm / 2.0
  let ext = self.center_to_seat_mm + self.socket_depth_mm
  match junction_port_mask(self.ports) {
    None => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    Some(mask) => {
      let x0 = if mask[1] { -ext } else { -r_out }
      let x1 = if mask[0] { ext } else { r_out }
      let y0 = if mask[3] { -ext } else { -r_out }
      let y1 = if mask[2] { ext } else { r_out }
      let z0 = if mask[5] { -ext } else { -r_out }
      let z1 = if mask[4] { ext } else { r_out }
      (x0, x1, y0, y1, z0, z1)
    }
  }
}

///|
fn pj_v_add(a : Vec3, b : Vec3) -> Vec3 {
  (a.0 + b.0, a.1 + b.1, a.2 + b.2)
}

///|
fn pj_v_scale(a : Vec3, s : Double) -> Vec3 {
  (a.0 * s, a.1 * s, a.2 * s)
}

///|
fn pj_right_handed_triad(a : Vec3, b : Vec3, w : Vec3) -> (Vec3, Vec3, Bool) {
  if v_dot(v_cross(b, w), a) >= 0.0 {
    (b, w, false)
  } else {
    (w, b, true)
  }
}

///|
/// Emits a watertight closed quad/tri surface mesh matching the exact
/// analytic `PipeJunction` geometry (for mesh export, glTF, Blender, volume,
/// and centroid computation).
pub fn pipe_junction_mesh(
  j : PipeJunction,
  quadrant_segs~ : Int32 = 16,
) -> (Array[Vec3], Array[Array[Int32]]) {
  let mask = match junction_port_mask(j.ports) {
    Some(m) => m
    None => return ([], [])
  }
  if !j.validate() {
    return ([], [])
  }
  let n = quadrant_segs.to_int()
  let r_out = j.outer_diameter_mm / 2.0
  let r_flow = j.through_bore_mm / 2.0
  let r_sock = j.socket_bore_mm / 2.0
  let lay = j.center_to_seat_mm
  let z_mouth = lay + j.socket_depth_mm
  let c = j.mouth_chamfer_mm
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let vert_map : Map[String, Int32] = Map([])
  let add_v = fn(p : Vec3) -> Int32 {
    let kx = @math.round(p.0 * 1.0e6).to_int64()
    let ky = @math.round(p.1 * 1.0e6).to_int64()
    let kz = @math.round(p.2 * 1.0e6).to_int64()
    let key = "\{kx},\{ky},\{kz}"
    match vert_map.get(key) {
      Some(idx) => idx
      None => {
        let idx = verts.length()
        verts.push(p)
        vert_map.set(key, idx)
        idx
      }
    }
  }
  let emit_tri = fn(a : Int32, b : Int32, d : Int32, outward : Bool) {
    if a != b && b != d && d != a {
      if outward {
        faces.push([a, b, d])
      } else {
        faces.push([a, d, b])
      }
    }
  }
  let emit_quad = fn(
    a : Int32,
    b : Int32,
    d : Int32,
    e : Int32,
    outward : Bool,
  ) {
    if outward {
      faces.push([a, b, d, e])
    } else {
      faces.push([a, e, d, b])
    }
  }
  let miter_clip = fn(th : Double, hb : Bool, hw : Bool) -> Double {
    let z_b = if hb { @math.cos(th) } else { 0.0 }
    let z_w = if hw { @math.sin(th) } else { 0.0 }
    if z_b > z_w {
      z_b
    } else {
      z_w
    }
  }
  let emit_shell_mesh = fn(r : Double, arm_len : Double, outward : Bool) {
    let signs = [-1.0, 1.0]
    for sx in signs {
      for sy in signs {
        for sz in signs {
          let hx = mask[if sx > 0.0 { 0 } else { 1 }]
          let hy = mask[if sy > 0.0 { 2 } else { 3 }]
          let hz = mask[if sz > 0.0 { 4 } else { 5 }]
          let ax : Vec3 = (sx, 0.0, 0.0)
          let ay : Vec3 = (0.0, sy, 0.0)
          let az : Vec3 = (0.0, 0.0, sz)
          if !hx && !hy && !hz {
            // 1/8 sphere in octant (ax, ay, az).
            let (u, v, _) = pj_right_handed_triad(az, ax, ay)
            let nu = n / 2
            let m = if nu < 4 { 4 } else { nu }
            for i in 0..<m {
              let ph0 = @math.PI / 2.0 * i.to_double() / m.to_double()
              let ph1 = @math.PI / 2.0 * (i + 1).to_double() / m.to_double()
              let row_cols = m - i
              for k in 0..<row_cols {
                let t0 = @math.PI / 2.0 * k.to_double() / row_cols.to_double()
                let t1 = @math.PI /
                  2.0 *
                  (k + 1).to_double() /
                  row_cols.to_double()
                let s_pt = fn(ph : Double, th : Double) -> Int32 {
                  let cp = @math.cos(ph)
                  let sp = @math.sin(ph)
                  let p = pj_v_add(
                    pj_v_scale(
                      pj_v_add(
                        pj_v_scale(u, cp * @math.cos(th)),
                        pj_v_scale(v, cp * @math.sin(th)),
                      ),
                      r,
                    ),
                    pj_v_scale(az, r * sp),
                  )
                  add_v(p)
                }
                if i == m - 1 {
                  let p0 = s_pt(ph0, 0.0)
                  let p1 = s_pt(ph0, @math.PI / 2.0)
                  let p2 = add_v(pj_v_scale(az, r))
                  emit_tri(p0, p1, p2, outward)
                } else {
                  let top_cols = row_cols - 1
                  let tt0 = @math.PI /
                    2.0 *
                    (k.to_double() / top_cols.to_double())
                  let tt1 = if k + 1 <= top_cols {
                    @math.PI /
                    2.0 *
                    ((k + 1).to_double() / top_cols.to_double())
                  } else {
                    @math.PI / 2.0
                  }
                  let a = s_pt(ph0, t0)
                  let b = s_pt(ph0, t1)
                  let d = s_pt(ph1, tt1)
                  let e = s_pt(ph1, tt0)
                  if d == e {
                    emit_tri(a, b, d, outward)
                  } else {
                    emit_quad(a, b, d, e, outward)
                  }
                }
              }
            }
          } else {
            let arms : Array[(Bool, Vec3, Bool, Vec3, Bool, Vec3)] = [
              (hx, ax, hy, ay, hz, az),
              (hy, ay, hz, az, hx, ax),
              (hz, az, hx, ax, hy, ay),
            ]
            for item in arms {
              let (ha, a, hb0, b0, hw0, w0) = item
              if ha {
                let (b, w, swapped) = pj_right_handed_triad(a, b0, w0)
                let (hb, hw) = if swapped { (hw0, hb0) } else { (hb0, hw0) }
                for i in 0..<n {
                  let th0 = @math.PI / 2.0 * i.to_double() / n.to_double()
                  let th1 = @math.PI / 2.0 * (i + 1).to_double() / n.to_double()
                  let z0 = r * miter_clip(th0, hb, hw)
                  let z1 = r * miter_clip(th1, hb, hw)
                  let rad0 = pj_v_add(
                    pj_v_scale(b, r * @math.cos(th0)),
                    pj_v_scale(w, r * @math.sin(th0)),
                  )
                  let rad1 = pj_v_add(
                    pj_v_scale(b, r * @math.cos(th1)),
                    pj_v_scale(w, r * @math.sin(th1)),
                  )
                  let p0 = add_v(pj_v_add(rad0, pj_v_scale(a, z0)))
                  let p1 = add_v(pj_v_add(rad1, pj_v_scale(a, z1)))
                  let p2 = add_v(pj_v_add(rad1, pj_v_scale(a, arm_len)))
                  let p3 = add_v(pj_v_add(rad0, pj_v_scale(a, arm_len)))
                  emit_quad(p0, p1, p2, p3, outward)
                }
              }
            }
          }
        }
      }
    }
  }
  emit_shell_mesh(r_out, z_mouth - c, true)
  emit_shell_mesh(r_flow, lay, false)
  let profile_pts : Array[(Double, Double)] = if c > 0.0 {
    [
      (r_out, z_mouth - c),
      (r_out - c, z_mouth),
      (r_sock + c, z_mouth),
      (r_sock, z_mouth - c),
      (r_sock, lay),
      (r_flow, lay),
    ]
  } else {
    [(r_out, z_mouth), (r_sock, z_mouth), (r_sock, lay), (r_flow, lay)]
  }
  for port_idx in 0..<6 {
    if mask[port_idx] {
      let a : Vec3 = match port_idx {
        0 => (1.0, 0.0, 0.0)
        1 => (-1.0, 0.0, 0.0)
        2 => (0.0, 1.0, 0.0)
        3 => (0.0, -1.0, 0.0)
        4 => (0.0, 0.0, 1.0)
        _ => (0.0, 0.0, -1.0)
      }
      let ref0 : Vec3 = if a.2.abs() > 0.5 {
        (1.0, 0.0, 0.0)
      } else {
        (0.0, 0.0, 1.0)
      }
      let b0 = ref0
      let w0 = v_cross(a, b0)
      let total = n * 4
      for s in 0..<(profile_pts.length() - 1) {
        let (r0, z0) = profile_pts[s]
        let (r1, z1) = profile_pts[s + 1]
        for i in 0..<total {
          let th0 = 2.0 * @math.PI * i.to_double() / total.to_double()
          let th1 = 2.0 * @math.PI * (i + 1).to_double() / total.to_double()
          let d0 = pj_v_add(
            pj_v_scale(b0, @math.cos(th0)),
            pj_v_scale(w0, @math.sin(th0)),
          )
          let d1 = pj_v_add(
            pj_v_scale(b0, @math.cos(th1)),
            pj_v_scale(w0, @math.sin(th1)),
          )
          let q00 = add_v(pj_v_add(pj_v_scale(a, z0), pj_v_scale(d0, r0)))
          let q01 = add_v(pj_v_add(pj_v_scale(a, z0), pj_v_scale(d1, r0)))
          let q11 = add_v(pj_v_add(pj_v_scale(a, z1), pj_v_scale(d1, r1)))
          let q10 = add_v(pj_v_add(pj_v_scale(a, z1), pj_v_scale(d0, r1)))
          emit_quad(q00, q01, q11, q10, true)
        }
      }
    }
  }
  (verts, faces)
}

///|
/// PipeJunction::volume_centroid computes signed volume and center of mass
/// using divergence theorem on the closed junction mesh.
pub fn PipeJunction::volume_centroid(self : PipeJunction) -> (Double, Vec3) {
  let (verts, faces) = pipe_junction_mesh(self, quadrant_segs=24)
  if verts.is_empty() || faces.is_empty() {
    return (0.0, (0.0, 0.0, 0.0))
  }
  let mut vol6 = 0.0
  let mut mx = 0.0
  let mut my = 0.0
  let mut mz = 0.0
  let acc_tri = fn(a : Vec3, b : Vec3, d : Vec3) {
    let dv = v_dot(a, v_cross(b, d))
    vol6 = vol6 + dv
    mx = mx + dv * (a.0 + b.0 + d.0)
    my = my + dv * (a.1 + b.1 + d.1)
    mz = mz + dv * (a.2 + b.2 + d.2)
  }
  for f in faces {
    let a = verts[f[0]]
    for k in 1..<(f.length() - 1) {
      acc_tri(a, verts[f[k]], verts[f[k + 1]])
    }
  }
  let vol = vol6 / 6.0
  if vol <= CAD_LENGTH_EPS {
    (0.0, (0.0, 0.0, 0.0))
  } else {
    let scale = 1.0 / (4.0 * vol6)
    (vol, (mx * scale, my * scale, mz * scale))
  }
}

///|
/// PipeJunction::volume returns the solid volume in mm^3.
pub fn PipeJunction::volume(self : PipeJunction) -> Double {
  let (v, _) = self.volume_centroid()
  v
}

///|
/// PipeJunction::centroid returns the solid center of mass in the local frame.
pub fn PipeJunction::centroid(self : PipeJunction) -> Vec3 {
  let (_, c) = self.volume_centroid()
  c
}

///|
fn pj_vkey(p : Vec3) -> String {
  let kx = @math.round(p.0 * 1.0e6).to_int64()
  let ky = @math.round(p.1 * 1.0e6).to_int64()
  let kz = @math.round(p.2 * 1.0e6).to_int64()
  "\{kx},\{ky},\{kz}"
}

///|
fn pj_ekey(p0 : Vec3, p1 : Vec3) -> String {
  let k0 = pj_vkey(p0)
  let k1 = pj_vkey(p1)
  if k0 < k1 {
    "\{k0}|\{k1}"
  } else {
    "\{k1}|\{k0}"
  }
}

///|
/// compile_pipe_junction emits one closed, trimmed analytic `MANIFOLD_SOLID_BREP`
/// for an orthogonal multi-port junction using exact `CYLINDRICAL_SURFACE`,
/// `SPHERICAL_SURFACE`, `CONICAL_SURFACE`, and `PLANE` faces joined along shared
/// `LINE`, `CIRCLE`, and `ELLIPSE` edges.
pub fn compile_pipe_junction(
  ctx : StepContext,
  node : SceneNode,
  junction : PipeJunction,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let mask = match junction_port_mask(junction.ports) {
    Some(m) => m
    None => return []
  }
  if !junction.validate() {
    return []
  }
  let xform = node_transform(node, parent)
  let r_out = junction.outer_diameter_mm / 2.0
  let r_flow = junction.through_bore_mm / 2.0
  let r_sock = junction.socket_bore_mm / 2.0
  let lay = junction.center_to_seat_mm
  let z_mouth = lay + junction.socket_depth_mm
  let c = junction.mouth_chamfer_mm

  let verts : Map[String, @step.Ref] = Map([])
  // Edge cache: unordered endpoint pair -> (edge_curve_ref, start_key, end_key)
  let edges : Map[String, (@step.Ref, String, String)] = Map([])

  let get_vp = fn(p_local : Vec3) -> @step.Ref {
    let k = pj_vkey(p_local)
    match verts.get(k) {
      Some(v) => v
      None => {
        let w = xform.apply(p_local)
        let vp = ctx.vertex_point(ctx.cartesian_point(w.0, w.1, w.2))
        verts.set(k, vp)
        vp
      }
    }
  }

  let get_edge = fn(
    p0_local : Vec3,
    p1_local : Vec3,
    canon_start : Vec3,
    canon_end : Vec3,
    build_curve : () -> @step.Ref,
  ) -> @step.Ref {
    let k = pj_ekey(p0_local, p1_local)
    let k0 = pj_vkey(p0_local)
    let ks = pj_vkey(canon_start)
    let ke = pj_vkey(canon_end)
    let edge_ref = match edges.get(k) {
      Some((er, _, _)) => er
      None => {
        let curve_ref = build_curve()
        let er = ctx.edge_curve(
          get_vp(canon_start),
          get_vp(canon_end),
          curve_ref,
          true,
        )
        edges.set(k, (er, ks, ke))
        er
      }
    }
    let (_, stored_s, _) = edges.get(k).unwrap()
    ctx.oriented_edge(edge_ref, k0 == stored_s)
  }

  let line_oe = fn(p0 : Vec3, p1 : Vec3) -> @step.Ref {
    get_edge(p0, p1, p0, p1, fn() {
      let w0 = xform.apply(p0)
      let dir = v_norm(xform.apply_dir(v_sub(p1, p0)))
      let len = v_len(v_sub(p1, p0))
      let cp = ctx.cartesian_point(w0.0, w0.1, w0.2)
      let dr = ctx.direction(dir.0, dir.1, dir.2)
      let vec = ctx.add(
        @repository.any_entity_vector(@geometry.Vector::new("", dr, len)),
      )
      ctx.line(cp, vec)
    })
  }

  let circle_oe = fn(
    center : Vec3,
    r : Double,
    p0 : Vec3,
    p1 : Vec3,
  ) -> @step.Ref {
    // Orient circle plane so angle increases from p0 to p1.
    let v0 = v_sub(p0, center)
    let v1 = v_sub(p1, center)
    let axis_local = v_norm(v_cross(v0, v1))
    let ref_local = v_norm(v0)
    get_edge(p0, p1, p0, p1, fn() {
      let cw = xform.apply(center)
      let axw = v_norm(xform.apply_dir(axis_local))
      let rfw = v_norm(xform.apply_dir(ref_local))
      let a2p = ctx.axis2_placement_3d(
        ctx.cartesian_point(cw.0, cw.1, cw.2),
        ctx.direction(axw.0, axw.1, axw.2),
        ctx.direction(rfw.0, rfw.1, rfw.2),
      )
      ctx.add(
        @repository.any_entity_circle(
          @geometry.Circle::new("", a2p, @step.fmt_num(r)),
        ),
      )
    })
  }

  // Canonical ellipse along miter plane of axes a, b with perpendicular w:
  // P(alpha) = (sqrt(2) * r) * cos(alpha) * (a + b) / sqrt(2) + r * sin(alpha) * w.
  // Parameter increases monotonically from P(0) = r*(a+b) to P(pi/2) = r*w.
  let ellipse_oe = fn(
    p0 : Vec3,
    p1 : Vec3,
    a : Vec3,
    b : Vec3,
    w_dir : Vec3,
    r : Double,
    forward : Bool,
  ) -> @step.Ref {
    let (cs, ce) = if forward { (p0, p1) } else { (p1, p0) }
    get_edge(p0, p1, cs, ce, fn() {
      let maj_local = v_norm(pj_v_add(a, b))
      let n_local = v_norm(v_cross(maj_local, w_dir))
      let cw = xform.apply((0.0, 0.0, 0.0))
      let nw = v_norm(xform.apply_dir(n_local))
      let mw = v_norm(xform.apply_dir(maj_local))
      let a2p = ctx.axis2_placement_3d(
        ctx.cartesian_point(cw.0, cw.1, cw.2),
        ctx.direction(nw.0, nw.1, nw.2),
        ctx.direction(mw.0, mw.1, mw.2),
      )
      ctx.add(
        @repository.any_entity_ellipse(
          @geometry.Ellipse::new(
            "",
            a2p,
            @step.fmt_num(Double::sqrt(2.0) * r),
            @step.fmt_num(r),
          ),
        ),
      )
    })
  }

  let emit_face_from_edges = fn(
    forward_edges : Array[() -> @step.Ref],
    reverse_edges : Array[() -> @step.Ref],
    surface_ref : @step.Ref,
    same_sense : Bool,
    flip_loop : Bool,
  ) -> @step.Ref {
    let oes : Array[@step.Ref] = []
    if !flip_loop {
      for f in forward_edges {
        oes.push(f())
      }
    } else {
      let count = reverse_edges.length()
      for i in 0..<count {
        oes.push(reverse_edges[count - 1 - i]())
      }
    }
    let lp = ctx.edge_loop(oes)
    let bound = ctx.face_outer_bound(lp, true)
    ctx.advanced_face([bound], surface_ref, same_sense)
  }

  let faces : Array[@step.Ref] = []

  let cyl_surf = fn(
    origin_local : Vec3,
    axis_local : Vec3,
    ref_local : Vec3,
    r : Double,
  ) -> @step.Ref {
    let ow = xform.apply(origin_local)
    let axw = v_norm(xform.apply_dir(axis_local))
    let rfw = v_norm(xform.apply_dir(ref_local))
    let a2p = ctx.axis2_placement_3d(
      ctx.cartesian_point(ow.0, ow.1, ow.2),
      ctx.direction(axw.0, axw.1, axw.2),
      ctx.direction(rfw.0, rfw.1, rfw.2),
    )
    ctx.add(
      @repository.any_entity_cylindrical_surface(
        @geometry.CylindricalSurface::new("", a2p, @step.fmt_num(r)),
      ),
    )
  }

  let sphere_surf = fn(r : Double) -> @step.Ref {
    let cw = xform.apply((0.0, 0.0, 0.0))
    let zw = v_norm(xform.apply_dir((0.0, 0.0, 1.0)))
    let xw = v_norm(xform.apply_dir((1.0, 0.0, 0.0)))
    let a2p = ctx.axis2_placement_3d(
      ctx.cartesian_point(cw.0, cw.1, cw.2),
      ctx.direction(zw.0, zw.1, zw.2),
      ctx.direction(xw.0, xw.1, xw.2),
    )
    ctx.add(
      @repository.any_entity_spherical_surface(
        @geometry.SphericalSurface::new("", a2p, @step.fmt_num(r)),
      ),
    )
  }

  let emit_shell_faces = fn(r : Double, arm_len : Double, outward : Bool) {
    let surf_sense = if outward { !reverse } else { reverse }
    let flip_loop = !outward
    let signs = [-1.0, 1.0]
    let inv_s2 = 1.0 / Double::sqrt(2.0)
    for sx in signs {
      for sy in signs {
        for sz in signs {
          let hx = mask[if sx > 0.0 { 0 } else { 1 }]
          let hy = mask[if sy > 0.0 { 2 } else { 3 }]
          let hz = mask[if sz > 0.0 { 4 } else { 5 }]
          let ax : Vec3 = (sx, 0.0, 0.0)
          let ay : Vec3 = (0.0, sy, 0.0)
          let az : Vec3 = (0.0, 0.0, sz)
          if !hx && !hy && !hz {
            let (u, v, _) = pj_right_handed_triad(az, ax, ay)
            let pu = pj_v_scale(u, r)
            let pv = pj_v_scale(v, r)
            let pn = pj_v_scale(az, r)
            let fwd : Array[() -> @step.Ref] = [
              fn() { circle_oe((0.0, 0.0, 0.0), r, pu, pv) },
              fn() { circle_oe((0.0, 0.0, 0.0), r, pv, pn) },
              fn() { circle_oe((0.0, 0.0, 0.0), r, pn, pu) },
            ]
            let rev : Array[() -> @step.Ref] = [
              fn() { circle_oe((0.0, 0.0, 0.0), r, pv, pu) },
              fn() { circle_oe((0.0, 0.0, 0.0), r, pn, pv) },
              fn() { circle_oe((0.0, 0.0, 0.0), r, pu, pn) },
            ]
            faces.push(
              emit_face_from_edges(
                fwd,
                rev,
                sphere_surf(r),
                surf_sense,
                flip_loop,
              ),
            )
          } else {
            let arms : Array[(Bool, Vec3, Bool, Vec3, Bool, Vec3)] = [
              (hx, ax, hy, ay, hz, az),
              (hy, ay, hz, az, hx, ax),
              (hz, az, hx, ax, hy, ay),
            ]
            for item in arms {
              let (ha, a, hb0, b0, hw0, w0) = item
              if ha {
                let (b, w, swapped) = pj_right_handed_triad(a, b0, w0)
                let (hb, hw) = if swapped { (hw0, hb0) } else { (hb0, hw0) }
                let pb = if hb {
                  pj_v_scale(pj_v_add(a, b), r)
                } else {
                  pj_v_scale(b, r)
                }
                let pw = if hw {
                  pj_v_scale(pj_v_add(a, w), r)
                } else {
                  pj_v_scale(w, r)
                }
                let top_c = pj_v_scale(a, arm_len)
                let pb_top = pj_v_add(top_c, pj_v_scale(b, r))
                let pw_top = pj_v_add(top_c, pj_v_scale(w, r))
                let fwd : Array[() -> @step.Ref] = []
                let rev : Array[() -> @step.Ref] = []
                if !hb && !hw {
                  fwd.push(fn() { circle_oe((0.0, 0.0, 0.0), r, pb, pw) })
                  rev.push(fn() { circle_oe((0.0, 0.0, 0.0), r, pw, pb) })
                } else if hb && !hw {
                  fwd.push(fn() { ellipse_oe(pb, pw, a, b, w, r, true) })
                  rev.push(fn() { ellipse_oe(pw, pb, a, b, w, r, false) })
                } else if !hb && hw {
                  fwd.push(fn() { ellipse_oe(pb, pw, a, w, b, r, false) })
                  rev.push(fn() { ellipse_oe(pw, pb, a, w, b, r, true) })
                } else {
                  let p_mid = pj_v_scale(
                    pj_v_add(a, pj_v_add(b, w)),
                    r * inv_s2,
                  )
                  fwd.push(fn() { ellipse_oe(pb, p_mid, a, b, w, r, true) })
                  fwd.push(fn() { ellipse_oe(p_mid, pw, a, w, b, r, false) })
                  rev.push(fn() { ellipse_oe(p_mid, pb, a, b, w, r, false) })
                  rev.push(fn() { ellipse_oe(pw, p_mid, a, w, b, r, true) })
                }
                fwd.push(fn() { line_oe(pw, pw_top) })
                fwd.push(fn() { circle_oe(top_c, r, pw_top, pb_top) })
                fwd.push(fn() { line_oe(pb_top, pb) })
                rev.push(fn() { line_oe(pw_top, pw) })
                rev.push(fn() { circle_oe(top_c, r, pb_top, pw_top) })
                rev.push(fn() { line_oe(pb, pb_top) })
                let surf = cyl_surf((0.0, 0.0, 0.0), a, b, r)
                faces.push(
                  emit_face_from_edges(fwd, rev, surf, surf_sense, flip_loop),
                )
              }
            }
          }
        }
      }
    }
  }

  emit_shell_faces(r_out, z_mouth - c, true)
  emit_shell_faces(r_flow, lay, false)

  // Emit socket / chamfer / pipe-stop ring bands around each port opening.
  let bands : Array[(Double, Double, Double, Double)] = if c > 0.0 {
    [
      (r_out, z_mouth - c, r_out - c, z_mouth),
      (r_out - c, z_mouth, r_sock + c, z_mouth),
      (r_sock + c, z_mouth, r_sock, z_mouth - c),
      (r_sock, z_mouth - c, r_sock, lay),
      (r_sock, lay, r_flow, lay),
    ]
  } else {
    [
      (r_out, z_mouth, r_sock, z_mouth),
      (r_sock, z_mouth, r_sock, lay),
      (r_sock, lay, r_flow, lay),
    ]
  }

  for port_idx in 0..<6 {
    if mask[port_idx] {
      let a : Vec3 = match port_idx {
        0 => (1.0, 0.0, 0.0)
        1 => (-1.0, 0.0, 0.0)
        2 => (0.0, 1.0, 0.0)
        3 => (0.0, -1.0, 0.0)
        4 => (0.0, 0.0, 1.0)
        _ => (0.0, 0.0, -1.0)
      }
      let ref0 : Vec3 = if a.2.abs() > 0.5 {
        (1.0, 0.0, 0.0)
      } else {
        (0.0, 0.0, 1.0)
      }
      let w0 = v_cross(a, ref0)
      let quad_dirs : ReadOnlyArray[_] = [
        ref0,
        w0,
        pj_v_scale(ref0, -1.0),
        pj_v_scale(w0, -1.0),
      ]
      for band in bands {
        let (r0, z0, r1, z1) = band
        let dr = r1 - r0
        let dz = z1 - z0
        let (surf, band_sense) = if dz.abs() < CAD_LENGTH_EPS {
          // Planar annulus (pipe stop or mouth rim) facing +a (dz = 0, dr < 0 -> +a).
          let ow = xform.apply(pj_v_scale(a, z0))
          let nw = v_norm(xform.apply_dir(a))
          let rw = v_norm(xform.apply_dir(ref0))
          let a2p = ctx.axis2_placement_3d(
            ctx.cartesian_point(ow.0, ow.1, ow.2),
            ctx.direction(nw.0, nw.1, nw.2),
            ctx.direction(rw.0, rw.1, rw.2),
          )
          let p = ctx.add(
            @repository.any_entity_plane(@geometry.Plane::new("", a2p)),
          )
          (p, !reverse)
        } else if dr.abs() < CAD_LENGTH_EPS {
          // Cylindrical socket bore (dz < 0 -> inward normal).
          (cyl_surf(pj_v_scale(a, z0), a, ref0, r0), reverse)
        } else {
          // Conical chamfer: origin at (r0, z0); cone_axis aligns radius growth.
          let alpha = @math.atan((dr / dz).abs())
          let cone_axis = if dr * dz < 0.0 { pj_v_scale(a, -1.0) } else { a }
          let ow = xform.apply(pj_v_scale(a, z0))
          let cw_ax = v_norm(xform.apply_dir(cone_axis))
          let rw = v_norm(xform.apply_dir(ref0))
          let a2p = ctx.axis2_placement_3d(
            ctx.cartesian_point(ow.0, ow.1, ow.2),
            ctx.direction(cw_ax.0, cw_ax.1, cw_ax.2),
            ctx.direction(rw.0, rw.1, rw.2),
          )
          let cone = ctx.add(
            @repository.any_entity_conical_surface(
              @geometry.ConicalSurface::new(
                "",
                a2p,
                @step.fmt_num(r0),
                @step.fmt_num(alpha),
              ),
            ),
          )
          let natural_outward = dr * dz < 0.0
          (cone, if natural_outward { !reverse } else { reverse })
        }
        let c0 = pj_v_scale(a, z0)
        let c1 = pj_v_scale(a, z1)
        for q in 0..<4 {
          let qb = quad_dirs[q]
          let qw = quad_dirs[(q + 1) % 4]
          let q00 = pj_v_add(c0, pj_v_scale(qb, r0))
          let q01 = pj_v_add(c0, pj_v_scale(qw, r0))
          let q11 = pj_v_add(c1, pj_v_scale(qw, r1))
          let q10 = pj_v_add(c1, pj_v_scale(qb, r1))
          let oe0 = circle_oe(c0, r0, q00, q01)
          let oe1 = line_oe(q01, q11)
          let oe2 = circle_oe(c1, r1, q11, q10)
          let oe3 = line_oe(q10, q00)
          let lp = ctx.edge_loop([oe0, oe1, oe2, oe3])
          let bound = ctx.face_outer_bound(lp, true)
          faces.push(ctx.advanced_face([bound], surf, band_sense))
        }
      }
    }
  }
  faces
}
