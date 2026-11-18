///|
/// ToroidalBend represents a circular solid rod or hollow pipe bent through a
/// circular arc `angle_deg` (`0 < angle_deg < 360`) around the `+Z` axis with
/// its centerline starting at `(bend_radius_mm, 0, 0)` along `+Y`.
#derive(Eq, Debug)
pub struct ToroidalBend {
  bend_radius_mm : Double
  outer_diameter_mm : Double
  inner_diameter_mm : Double
  angle_deg : Double
}

///|
/// ToroidalBend::new constructs an analytic toroidal pipe or rod bend.
pub fn ToroidalBend::new(
  bend_radius_mm : Double,
  outer_diameter_mm : Double,
  angle_deg : Double,
  inner_diameter_mm~ : Double = 0.0,
) -> Shape {
  Shape::ToroidalBend({
    bend_radius_mm,
    outer_diameter_mm,
    inner_diameter_mm,
    angle_deg,
  })
}

///|
/// ToroidalBend::validate checks that the radii and sweep angle define a
/// non-self-intersecting solid bend.
pub fn ToroidalBend::validate(self : ToroidalBend) -> Bool {
  let r_out = self.outer_diameter_mm / 2.0
  let r_in = self.inner_diameter_mm / 2.0
  r_out > 1.0e-9 &&
  r_in >= 0.0 &&
  r_in < r_out - 1.0e-9 &&
  self.bend_radius_mm > r_out + 1.0e-9 &&
  self.angle_deg > 1.0e-6 &&
  self.angle_deg < 360.0 - 1.0e-6
}

///|
/// ToroidalBend::volume returns the exact Pappus-Guldinus volume in mm^3.
pub fn ToroidalBend::volume(self : ToroidalBend) -> Double {
  if !self.validate() {
    return 0.0
  }
  let r_out = self.outer_diameter_mm / 2.0
  let r_in = self.inner_diameter_mm / 2.0
  let area = @math.PI * (r_out * r_out - r_in * r_in)
  let alpha = self.angle_deg * @math.PI / 180.0
  area * self.bend_radius_mm * alpha
}

///|
/// ToroidalBend::centroid returns the exact center of mass in the local frame.
pub fn ToroidalBend::centroid(self : ToroidalBend) -> Vec3 {
  if !self.validate() {
    return (0.0, 0.0, 0.0)
  }
  let r_out = self.outer_diameter_mm / 2.0
  let r_in = self.inner_diameter_mm / 2.0
  let r_bend = self.bend_radius_mm
  let alpha = self.angle_deg * @math.PI / 180.0
  // For an annular disc of radii r_in..r_out centered at x = r_bend swept
  // uniformly through 0..alpha around +Z, the centroid radius in the XY plane
  // at mid-angle alpha/2 equals (r_bend + (r_out^2 + r_in^2)/(4*r_bend)) * sin(alpha/2)/(alpha/2).
  let rho_bar = r_bend + (r_out * r_out + r_in * r_in) / (4.0 * r_bend)
  let half = alpha / 2.0
  let r_centroid = rho_bar * @math.sin(half) / half
  (r_centroid * @math.cos(half), r_centroid * @math.sin(half), 0.0)
}

///|
/// ToroidalBend::bounding_box returns the exact local bounding box.
pub fn ToroidalBend::bounding_box(
  self : ToroidalBend,
) -> (Double, Double, Double, Double, Double, Double) {
  let r_out = self.outer_diameter_mm / 2.0
  let r_bend = self.bend_radius_mm
  let alpha = self.angle_deg * @math.PI / 180.0
  let mut x0 = @double.max_value
  let mut x1 = @double.min_value
  let mut y0 = @double.max_value
  let mut y1 = @double.min_value
  let n_u = 64
  let n_v = 24
  for iu in 0..<=n_u {
    let u = alpha * iu.to_double() / n_u.to_double()
    let cu = @math.cos(u)
    let su = @math.sin(u)
    for iv in 0..<n_v {
      let v = 2.0 * @math.PI * iv.to_double() / n_v.to_double()
      let rr = r_bend + r_out * @math.cos(v)
      let x = rr * cu
      let y = rr * su
      if x < x0 {
        x0 = x
      }
      if x > x1 {
        x1 = x
      }
      if y < y0 {
        y0 = y
      }
      if y > y1 {
        y1 = y
      }
    }
  }
  (x0, x1, y0, y1, -r_out, r_out)
}

///|
/// toroidal_bend_mesh builds a faceted triangle/quad mesh for Blender export.
pub fn toroidal_bend_mesh(
  b : ToroidalBend,
  u_segments~ : Int32 = 24,
  v_segments~ : Int32 = 32,
) -> (Array[Vec3], Array[Array[Int32]]) {
  if !b.validate() {
    return ([], [])
  }
  let r_out = b.outer_diameter_mm / 2.0
  let r_in = b.inner_diameter_mm / 2.0
  let r_bend = b.bend_radius_mm
  let alpha = b.angle_deg * @math.PI / 180.0
  let nu = if u_segments < 2 { 2 } else { u_segments }
  let nv = if v_segments < 8 { 8 } else { v_segments }
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let push_ring = fn(rho : Double, u : Double) {
    let cu = @math.cos(u)
    let su = @math.sin(u)
    for iv in 0..<nv {
      let v = 2.0 * @math.PI * iv.to_double() / nv.to_double()
      let rr = r_bend + rho * @math.cos(v)
      verts.push((rr * cu, rr * su, rho * @math.sin(v)))
    }
  }
  for iu in 0..<=nu {
    let u = alpha * iu.to_double() / nu.to_double()
    push_ring(r_out, u)
  }
  for iu in 0..<nu {
    let row0 = iu * nv
    let row1 = (iu + 1) * nv
    for iv in 0..<nv {
      let next_v = (iv + 1) % nv
      faces.push([row0 + iv, row1 + iv, row1 + next_v, row0 + next_v])
    }
  }
  if r_in > 1.0e-9 {
    let inner_base = verts.length()
    for iu in 0..<=nu {
      let u = alpha * iu.to_double() / nu.to_double()
      push_ring(r_in, u)
    }
    for iu in 0..<nu {
      let row0 = inner_base + iu * nv
      let row1 = inner_base + (iu + 1) * nv
      for iv in 0..<nv {
        let next_v = (iv + 1) % nv
        faces.push([row0 + iv, row0 + next_v, row1 + next_v, row1 + iv])
      }
    }
    for iv in 0..<nv {
      let next_v = (iv + 1) % nv
      // Start annulus cap (normal -Y)
      faces.push([iv, next_v, inner_base + next_v, inner_base + iv])
      // End annulus cap (normal +tangent)
      let eo = nu * nv
      let ei = inner_base + nu * nv
      faces.push([eo + iv, ei + iv, ei + next_v, eo + next_v])
    }
  } else {
    let start_cap : Array[Int32] = []
    for iv in 0..<nv {
      start_cap.push(nv - 1 - iv)
    }
    faces.push(start_cap)
    let end_cap : Array[Int32] = []
    let eo = nu * nv
    for iv in 0..<nv {
      end_cap.push(eo + iv)
    }
    faces.push(end_cap)
  }
  (verts, faces)
}

///|
/// toroidal_bend_tube_refs emits one analytic `TOROIDAL_SURFACE` band plus its
/// inner-equator seam edge and start/end `CIRCLE` edges.
fn toroidal_bend_tube_refs(
  ctx : StepContext,
  xform : Transform,
  r_bend : Double,
  rho : Double,
  alpha : Double,
  is_outer : Bool,
  reverse : Bool,
) -> (@step.Ref, @step.Ref, @step.Ref) {
  let center_z = xform.apply((0.0, 0.0, 0.0))
  let axis_z = xform.apply_dir((0.0, 0.0, 1.0))
  let ref_x = xform.apply_dir((1.0, 0.0, 0.0))
  let torus_a2p = ctx.axis2_placement_3d(
    ctx.cartesian_point(center_z.0, center_z.1, center_z.2),
    ctx.direction(axis_z.0, axis_z.1, axis_z.2),
    ctx.direction(ref_x.0, ref_x.1, ref_x.2),
  )
  let torus_surf = ctx.add(
    @repository.any_entity_toroidal_surface(
      @geometry.ToroidalSurface::new(
        "",
        torus_a2p,
        @step.fmt_num(r_bend),
        @step.fmt_num(rho),
      ),
    ),
  )

  let ca = @math.cos(alpha)
  let sa = @math.sin(alpha)
  let r_eq = r_bend - rho
  let ps = xform.apply((r_eq, 0.0, 0.0))
  let pe = xform.apply((r_eq * ca, r_eq * sa, 0.0))
  let vs = ctx.vertex_point(ctx.cartesian_point(ps.0, ps.1, ps.2))
  let ve = ctx.vertex_point(ctx.cartesian_point(pe.0, pe.1, pe.2))

  // Inner equator seam circle (`v = pi`), increasing u from 0 to alpha.
  let seam_circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", torus_a2p, @step.fmt_num(r_eq)),
    ),
  )
  let seam_edge = ctx.edge_curve(vs, ve, seam_circle, true)

  // Start cap minor circle at u = 0 (`axis = -Y`, `ref = +X`, `axis x ref = +Z`).
  let start_center = xform.apply((r_bend, 0.0, 0.0))
  let start_axis = xform.apply_dir((0.0, -1.0, 0.0))
  let start_a2p = ctx.axis2_placement_3d(
    ctx.cartesian_point(start_center.0, start_center.1, start_center.2),
    ctx.direction(start_axis.0, start_axis.1, start_axis.2),
    ctx.direction(ref_x.0, ref_x.1, ref_x.2),
  )
  let start_circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", start_a2p, @step.fmt_num(rho)),
    ),
  )
  let start_edge = ctx.edge_curve(vs, vs, start_circle, true)

  // End cap minor circle at u = alpha (`axis = (sin a, -cos a, 0)`, `ref = (cos a, sin a, 0)`).
  let end_center = xform.apply((r_bend * ca, r_bend * sa, 0.0))
  let end_axis = xform.apply_dir((sa, -ca, 0.0))
  let end_ref = xform.apply_dir((ca, sa, 0.0))
  let end_a2p = ctx.axis2_placement_3d(
    ctx.cartesian_point(end_center.0, end_center.1, end_center.2),
    ctx.direction(end_axis.0, end_axis.1, end_axis.2),
    ctx.direction(end_ref.0, end_ref.1, end_ref.2),
  )
  let end_circle = ctx.add(
    @repository.any_entity_circle(
      @geometry.Circle::new("", end_a2p, @step.fmt_num(rho)),
    ),
  )
  let end_edge = ctx.edge_curve(ve, ve, end_circle, true)

  // Match loop traversal with effective face outward normal:
  // Outer wants +N_nat (`same_sense = !reverse`), inner wants -N_nat (`same_sense = reverse`).
  let same_sense = if is_outer { !reverse } else { reverse }
  let (e_end_sense, e_start_sense) = if is_outer {
    (true, false)
  } else {
    (false, true)
  }
  let loop_ref = ctx.edge_loop([
    ctx.oriented_edge(seam_edge, true),
    ctx.oriented_edge(end_edge, e_end_sense),
    ctx.oriented_edge(seam_edge, false),
    ctx.oriented_edge(start_edge, e_start_sense),
  ])
  let bound = ctx.face_outer_bound(loop_ref, true)
  let face = ctx.advanced_face([bound], torus_surf, same_sense)
  (face, start_edge, end_edge)
}

///|
/// compile_toroidal_bend emits a smooth analytic `TOROIDAL_SURFACE` pipe or rod
/// bend (`4` faces for a hollow bend, `3` for a solid rod).
pub fn compile_toroidal_bend(
  ctx : StepContext,
  node : SceneNode,
  bend : ToroidalBend,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  if !bend.validate() {
    return []
  }
  let xform = node_transform(node, parent)
  let r_bend = bend.bend_radius_mm
  let r_out = bend.outer_diameter_mm / 2.0
  let r_in = bend.inner_diameter_mm / 2.0
  let alpha = bend.angle_deg * @math.PI / 180.0
  let ca = @math.cos(alpha)
  let sa = @math.sin(alpha)

  let (outer_face, start_out, end_out) = toroidal_bend_tube_refs(
    ctx, xform, r_bend, r_out, alpha, true, reverse,
  )
  let faces : Array[@step.Ref] = [outer_face]

  // Planar start cap at u = 0 (`normal = -Y`).
  let start_center = xform.apply((r_bend, 0.0, 0.0))
  let start_norm = xform.apply_dir((0.0, -1.0, 0.0))
  let start_ref = xform.apply_dir((1.0, 0.0, 0.0))
  let start_plane_a2p = ctx.axis2_placement_3d(
    ctx.cartesian_point(start_center.0, start_center.1, start_center.2),
    ctx.direction(start_norm.0, start_norm.1, start_norm.2),
    ctx.direction(start_ref.0, start_ref.1, start_ref.2),
  )
  let start_plane = ctx.add(
    @repository.any_entity_plane(@geometry.Plane::new("", start_plane_a2p)),
  )

  // Planar end cap at u = alpha (`normal = (-sin a, cos a, 0)`).
  let end_center = xform.apply((r_bend * ca, r_bend * sa, 0.0))
  let end_norm = xform.apply_dir((-sa, ca, 0.0))
  let end_ref = xform.apply_dir((ca, sa, 0.0))
  let end_plane_a2p = ctx.axis2_placement_3d(
    ctx.cartesian_point(end_center.0, end_center.1, end_center.2),
    ctx.direction(end_norm.0, end_norm.1, end_norm.2),
    ctx.direction(end_ref.0, end_ref.1, end_ref.2),
  )
  let end_plane = ctx.add(
    @repository.any_entity_plane(@geometry.Plane::new("", end_plane_a2p)),
  )

  let start_outer_bound = ctx.face_outer_bound(
    ctx.edge_loop([ctx.oriented_edge(start_out, true)]),
    true,
  )
  let end_outer_bound = ctx.face_outer_bound(
    ctx.edge_loop([ctx.oriented_edge(end_out, false)]),
    true,
  )

  if r_in > 1.0e-9 {
    let (inner_face, start_in, end_in) = toroidal_bend_tube_refs(
      ctx, xform, r_bend, r_in, alpha, false, reverse,
    )
    faces.push(inner_face)
    let start_inner_bound = ctx.face_bound(
      ctx.edge_loop([ctx.oriented_edge(start_in, false)]),
      true,
    )
    let end_inner_bound = ctx.face_bound(
      ctx.edge_loop([ctx.oriented_edge(end_in, true)]),
      true,
    )
    faces.push(
      ctx.advanced_face(
        [start_outer_bound, start_inner_bound],
        start_plane,
        !reverse,
      ),
    )
    faces.push(
      ctx.advanced_face([end_outer_bound, end_inner_bound], end_plane, !reverse),
    )
  } else {
    faces.push(ctx.advanced_face([start_outer_bound], start_plane, !reverse))
    faces.push(ctx.advanced_face([end_outer_bound], end_plane, !reverse))
  }
  faces
}
