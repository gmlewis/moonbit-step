///|
// Smooth back-cone bevel body.
//
// Each tooth is split at its two tip corners into three strips (start flank,
// tip land, end flank). Every strip is a clean ruled B-spline surface between
// its back and front profile curves, and its tooth-end cap is a ruled surface
// between the strip's back curve and a matching root-circle arc. Each tooth
// therefore contributes three side faces, three cap faces, and one gap root
// land: seven B-spline faces per tooth. The front and backing caps are planar
// faces bounded by the same curve edges, so every shared edge matches.
//
// Splitting at the tip corners removes the interior sharp creases and the
// large degenerate tooth-cap surface of the first smooth version. Both were
// flagged by stricter kernels (SolidCore reported non-monotonic B-spline
// control nets and near-cusp profile curves).

///|
/// bevel_curve_knots returns the degree and clamped knot data for a control
/// polygon of `m` sampled points (quadratic when possible).
fn bevel_curve_knots(m : Int32) -> (Int32, Array[Int32], Array[String]) {
  let degree = if m >= 3 { 2 } else { 1 }
  let spans = m - degree
  let mults : Array[Int32] = [degree + 1]
  for _ in 1..<spans {
    mults.push(1)
  }
  mults.push(degree + 1)
  let knots : Array[String] = []
  for i in 0..<=spans {
    knots.push(@step.fmt_num(i.to_double()))
  }
  (degree, mults, knots)
}

///|
/// bevel_smooth_curve emits a clamped B-spline curve whose control polygon is
/// the sampled profile itself: quadratic (degree 1 for a two-point segment).
/// Using the samples as control points keeps the control polygon monotonic,
/// which stricter kernels require; a cubic Bezier span fitted through the
/// samples can double back slightly near the root corner. The curve starts and
/// ends exactly at the first and last sample, so the sharp tip and root
/// corners stay exact across adjacent strips.
fn bevel_smooth_curve(
  ctx : StepContext,
  points : Array[Vec3],
) -> (SmoothCurve, @step.Ref, Int32, Array[Int32], Array[String]) {
  let m = points.length()
  let cps = points.map(fn(p) { ctx.cartesian_point(p.0, p.1, p.2) })
  let (degree, mults, knots) = bevel_curve_knots(m)
  let curve = @geometry.BSplineCurveWithKnots::new(
    "", degree, cps, ".UNSPECIFIED.", false, false, mults, knots, ".UNSPECIFIED.",
  )
  let curve_ref = ctx.add(
    @repository.any_entity_b_spline_curve_with_knots(curve),
  )
  let smooth : SmoothCurve = {
    curve_ref,
    cps,
    cps_pos: points,
    start_cp: cps[0],
    end_cp: cps[cps.length() - 1],
  }
  let edge = ctx.edge_curve(
    ctx.vertex_point(smooth.start_cp),
    ctx.vertex_point(smooth.end_cp),
    curve_ref,
    true,
  )
  (smooth, edge, degree, mults, knots)
}

///|
/// bevel_surface emits the ruled B-spline surface between two rows with the
/// given degree and knots in the profile direction. It is the quadratic
/// counterpart of `smooth_surface` (which is fixed at degree 3 with
/// piecewise-Bezier knots).
fn bevel_surface(
  ctx : StepContext,
  row_a : SmoothCurve,
  row_b : SmoothCurve,
  expected_out : Vec3,
  degree : Int32,
  mults : Array[Int32],
  knots : Array[String],
) -> (@step.Ref, Bool) {
  let du = v_sub(row_b.cps_pos[0], row_a.cps_pos[0])
  let dv = v_sub(row_a.cps_pos[1], row_a.cps_pos[0])
  let natural_normal = v_cross(du, dv)
  let (row0, row1) = if v_dot(natural_normal, expected_out) >= 0.0 {
    (row_a, row_b)
  } else {
    (row_b, row_a)
  }
  let cp_row = fn(row : Array[@step.Ref]) -> String {
    "(" + row.map(fn(r) { "#\{r.id.value}" }).join(",") + ")"
  }
  let rows = "(" + cp_row(row0.cps) + "," + cp_row(row1.cps) + ")"
  let mults_text = "(" + mults.map(fn(m) { "\{m}" }).join(",") + ")"
  let knots_text = "(" + knots.join(",") + ")"
  let args = "('',1," +
    degree.to_string() +
    "," +
    rows +
    ",.UNSPECIFIED.,.F.,.F.,.F.,(2,2)," +
    mults_text +
    ",(0.,1.)," +
    knots_text +
    ",.UNSPECIFIED.)"
  let raw = @step.RawEntity::new("B_SPLINE_SURFACE_WITH_KNOTS", args)
  let surface_ref = ctx.add(@repository.any_entity_raw_entity(raw))
  (surface_ref, true)
}

///|
/// bevel_smooth_tip_corners returns the first and last path indices whose
/// radius is the tooth's maximum. Those two points bound the tip land and are
/// the only interior corners of a tooth boundary; the flank and tip curves are
/// built between them so no curve carries an interior crease.
fn bevel_smooth_tip_corners(points : Array[Vec3]) -> Array[Int32] {
  let m = points.length()
  let mut rmax = 0.0
  for p in points {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if r > rmax {
      rmax = r
    }
  }
  let tol = @step.TOL_1E6 * (1.0 + rmax)
  let mut first = -1
  let mut last = -1
  for i, p in points {
    let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
    if i > 0 && i < m - 1 && (r - rmax).abs() <= tol {
      if first < 0 {
        first = i
      }
      last = i
    }
  }
  if first < 0 {
    []
  } else if first == last {
    [first]
  } else {
    [first, last]
  }
}

///|
/// bevel_face builds a single-bound face from a loop already wound for the
/// surface normal. Unlike `smooth_face`, which reverses the caller's cycle for
/// the helical-washer convention, this keeps the cycle as given so the loop
/// agrees with the B-spline surface's natural normal.
fn bevel_face(
  ctx : StepContext,
  edges : Array[(@step.Ref, Bool)],
  surface : @step.Ref,
  same_sense : Bool,
) -> @step.Ref {
  let oriented = edges.map(fn(e) { ctx.oriented_edge(e.0, e.1) })
  ctx.advanced_face(
    [ctx.face_outer_bound(ctx.edge_loop(oriented), true)],
    surface,
    same_sense,
  )
}

///|
/// BevelSmoothPatch is one side strip of a tooth: a ruled B-spline surface
/// between the back and front profile curves. Its back edge is shared with the
/// tooth's analytic back-cone face and its front edge with the front plane; the
/// root edge bounds the backing plane.
priv struct BevelSmoothPatch {
  back_curve : SmoothCurve
  front_curve : SmoothCurve
  back_edge : @step.Ref
  front_edge : @step.Ref
  root_edge : @step.Ref
  v_deg : Int32
  v_mults : Array[Int32]
  v_knots : Array[String]
  start_pos : Int32
  end_pos : Int32
}

///|
/// BevelFrontStrip is one strip of the front (small-end) boundary: the back
/// curve and the sampled front/back points, used to build the explicit
/// chamfer band. The strips are ordered around the whole outline (tooth
/// strips then the following gap strip).
priv struct BevelFrontStrip {
  back_curve : SmoothCurve
  back_pts : Array[Vec3]
  front_pts : Array[Vec3]
  back_edge : @step.Ref
  v_deg : Int32
  v_mults : Array[Int32]
  v_knots : Array[String]
}

///|
fn compile_bevel_gear_body_smooth(
  ctx : StepContext,
  node : SceneNode,
  e : BevelGearBody,
  reverse~ : Bool = false,
  parent~ : Transform? = None,
) -> Array[@step.Ref] {
  let xform = node_transform(node, parent)
  let n = e.back.length()
  if n < 3 ||
    e.front.length() != n ||
    e.teeth.is_empty() ||
    e.front_z_mm <= e.root_z_mm {
    return []
  }
  for tooth in e.teeth {
    let (start, end) = tooth
    if start < 0 || end >= n || end <= start {
      return []
    }
  }
  let (first_start, _) = e.teeth[0]
  let root_radius = Double::sqrt(
    e.back[first_start].0 * e.back[first_start].0 +
    e.back[first_start].1 * e.back[first_start].1,
  )
  if !(root_radius > e.bore_radius_mm) {
    return []
  }
  let front_offset = n
  let local_pts : Array[Vec3] = []
  local_pts.push_iter(e.back.iter())
  local_pts.push_iter(e.front.iter())
  let pts = local_pts.map(fn(p) { xform.apply(p) })
  let cp_refs = pts.map(fn(p) {
    let (px, py, pz) = p
    ctx.cartesian_point(px, py, pz)
  })
  let vp_refs = cp_refs.map(fn(cp) { ctx.vertex_point(cp) })
  let edges : Array[EdgeInfo] = []
  let seen : Map[String, Bool] = Map([])
  let add_edge = fn(a : Int32, b : Int32) -> Unit {
    if a == b {
      return
    }
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
    edges.push(EdgeInfo::{ start, end, edge: ec_ref, })
  }

  let two_pi = 2.0 * @math.PI
  let num_teeth = e.teeth.length()
  let patches_per_tooth : Array[Array[BevelSmoothPatch]] = []
  let gap_back_edges : Array[@step.Ref] = []
  let gap_front_edges : Array[@step.Ref] = []
  let gap_back_curves : Array[SmoothCurve] = []
  let gap_front_curves : Array[SmoothCurve] = []
  let gap_back_pts : Array[Array[Vec3]] = []
  let gap_front_pts : Array[Array[Vec3]] = []
  let gap_v_deg : Array[Int32] = []
  let gap_v_mults : Array[Array[Int32]] = []
  let gap_v_knots : Array[Array[String]] = []

  for k, tooth in e.teeth {
    let (start, end) = tooth
    let count = end - start + 1
    let tooth_back : Array[Vec3] = []
    let tooth_front : Array[Vec3] = []
    for i in start..<=end {
      tooth_back.push(local_pts[i])
      tooth_front.push(local_pts[front_offset + i])
    }
    // Segment boundaries: tooth start, each tip corner, tooth end. The builder
    // supplies the exact tip-land indices; fall back to a radius scan only for
    // callers that construct BevelGearBody directly.
    let corners = if k < e.tips.length() {
      let (tip_start, tip_end) = e.tips[k]
      [tip_start - start, tip_end - start]
    } else {
      bevel_smooth_tip_corners(tooth_back)
    }
    let boundaries : Array[Int32] = [0]
    for corner in corners {
      if corner > boundaries[boundaries.length() - 1] && corner < count - 1 {
        boundaries.push(corner)
      }
    }
    boundaries.push(count - 1)
    // Cross edges at every strip boundary for the side surfaces.
    for j in 0..<boundaries.length() {
      let b = boundaries[j]
      add_edge(start + b, front_offset + start + b)
    }
    // Root-circle points under this tooth, shared by the root arcs, the
    // analytic back-cone face, and the backing plane.
    let root_point_at = fn(ang : Double) -> Vec3 {
      (root_radius * @math.cos(ang), root_radius * @math.sin(ang), e.root_z_mm)
    }
    let tooth_patches : Array[BevelSmoothPatch] = []
    for j in 0..<(boundaries.length() - 1) {
      let b0 = boundaries[j]
      let b1 = boundaries[j + 1]
      let seg_count = b1 - b0 + 1
      let back_pts : Array[Vec3] = []
      let front_pts : Array[Vec3] = []
      for i in b0..<=b1 {
        back_pts.push(xform.apply(local_pts[start + i]))
        front_pts.push(xform.apply(local_pts[front_offset + start + i]))
      }
      let (bc, be, v_deg, v_mults, v_knots) = bevel_smooth_curve(ctx, back_pts)
      let (fc, fe, _, _, _) = bevel_smooth_curve(ctx, front_pts)
      // Root arc over the strip's azimuth range. Interior endpoints use the
      // exact boundary angle so the shared radial cut and both root curves
      // meet at one vertex.
      let a0 = @math.atan2(local_pts[start + b0].1, local_pts[start + b0].0)
      let a1 = @math.atan2(local_pts[start + b1].1, local_pts[start + b1].0)
      let raw = a1 - a0
      let mut delta = raw - two_pi * Double::floor(raw / two_pi)
      if delta <= @step.TOL_1E12 {
        delta = delta + two_pi
      }
      let root_points : Array[Vec3] = []
      for i in 0..<seg_count {
        let root_local_pt = if i == 0 && b0 == 0 {
          local_pts[start]
        } else if i == seg_count - 1 && b1 == count - 1 {
          local_pts[end]
        } else {
          let ang = if i == 0 {
            a0
          } else if i == seg_count - 1 {
            a1
          } else {
            a0 + delta * i.to_double() / (seg_count - 1).to_double()
          }
          root_point_at(ang)
        }
        root_points.push(xform.apply(root_local_pt))
      }
      let (_, re, _, _, _) = bevel_smooth_curve(ctx, root_points)
      tooth_patches.push(BevelSmoothPatch::{
        back_curve: bc,
        front_curve: fc,
        back_edge: be,
        front_edge: fe,
        root_edge: re,
        v_deg,
        v_mults,
        v_knots,
        start_pos: start + b0,
        end_pos: start + b1,
      })
    }
    patches_per_tooth.push(tooth_patches)
  }

  // Gap root lands between consecutive teeth.
  for k in 0..<num_teeth {
    let end = e.teeth[k].1
    let next_start = e.teeth[(k + 1) % num_teeth].0
    let gap_back : Array[Vec3] = []
    let gap_front : Array[Vec3] = []
    let mut idx = end
    while true {
      gap_back.push(xform.apply(local_pts[idx]))
      gap_front.push(xform.apply(local_pts[front_offset + idx]))
      if idx == next_start {
        break
      }
      idx = (idx + 1) % n
    }
    let (bc, be, g_deg, g_mults, g_knots) = bevel_smooth_curve(ctx, gap_back)
    let (fc, fe, _, _, _) = bevel_smooth_curve(ctx, gap_front)
    gap_back_curves.push(bc)
    gap_front_curves.push(fc)
    gap_back_edges.push(be)
    gap_front_edges.push(fe)
    gap_back_pts.push(gap_back)
    gap_front_pts.push(gap_front)
    gap_v_deg.push(g_deg)
    gap_v_mults.push(g_mults)
    gap_v_knots.push(g_knots)
  }

  let face_refs : Array[@step.Ref] = []

  // Shared analytic back-cone surface for every tooth-end face. The tooth ends
  // are trimmed faces on this cone (as in the McMaster goldens), so no
  // B-spline end caps are needed.
  let up = xform.apply_dir((0.0, 0.0, 1.0))
  let right = xform.apply_dir((1.0, 0.0, 0.0))
  let down = xform.apply_dir((0.0, 0.0, -1.0))
  let dir_up = ctx.direction(up.0, up.1, up.2)
  let dir_right = ctx.direction(right.0, right.1, right.2)
  let cone_origin = xform.apply((0.0, 0.0, e.root_z_mm))
  let cp_cone = ctx.cartesian_point(cone_origin.0, cone_origin.1, cone_origin.2)
  let a2p_cone = ctx.axis2_placement_3d(cp_cone, dir_up, dir_right)
  let cone_ref = ctx.add(
    @repository.any_entity_conical_surface(
      @geometry.ConicalSurface::new(
        "",
        a2p_cone,
        @step.fmt_num(root_radius),
        @step.fmt_num(@math.atan(e.cone_tan_half_angle)),
      ),
    ),
  )

  // The front cap is bounded by the front side edges normally, or by the
  // inset inner rails when an explicit chamfer band is built.
  let front_plane_edges : Array[@step.Ref] = []

  if e.chamfer_mm > 0.0 {
    let chamfer = e.chamfer_mm
    let front_z = e.front_z_mm
    // Front-boundary strips in loop order: tooth strips then the gap strip.
    let strips : Array[BevelFrontStrip] = []
    for k in 0..<num_teeth {
      for patch in patches_per_tooth[k] {
        let bpts : Array[Vec3] = []
        let fpts : Array[Vec3] = []
        for i in patch.start_pos..<=patch.end_pos {
          bpts.push(xform.apply(local_pts[i]))
          fpts.push(xform.apply(local_pts[front_offset + i]))
        }
        strips.push(BevelFrontStrip::{
          back_curve: patch.back_curve,
          back_pts: bpts,
          front_pts: fpts,
          back_edge: patch.back_edge,
          v_deg: patch.v_deg,
          v_mults: patch.v_mults,
          v_knots: patch.v_knots,
        })
      }
      strips.push(BevelFrontStrip::{
        back_curve: gap_back_curves[k],
        back_pts: gap_back_pts[k],
        front_pts: gap_front_pts[k],
        back_edge: gap_back_edges[k],
        v_deg: gap_v_deg[k],
        v_mults: gap_v_mults[k],
        v_knots: gap_v_knots[k],
      })
    }
    let strip_count = strips.length()
    let inner_pts : Array[Array[Vec3]] = []
    let outer_pts : Array[Array[Vec3]] = []
    for j in 0..<strip_count {
      let s = strips[j]
      let count = s.front_pts.length()
      let ip : Array[Vec3] = []
      let op : Array[Vec3] = []
      for i in 0..<count {
        let p = s.front_pts[i]
        // Radial edge break: preserve every angular position so the tooth
        // widths stay constant in the axial view, as in the goldens.
        let r = Double::sqrt(p.0 * p.0 + p.1 * p.1)
        let scale = if r > CAD_LENGTH_EPS { (r - chamfer) / r } else { 1.0 }
        ip.push((p.0 * scale, p.1 * scale, front_z))
        let bp = s.back_pts[i]
        let dz = front_z - bp.2
        let t = if Double::abs(dz) > @step.TOL_1E12 {
          chamfer / dz
        } else {
          0.0
        }
        op.push(
          (p.0 + t * (bp.0 - p.0), p.1 + t * (bp.1 - p.1), front_z - chamfer),
        )
      }
      inner_pts.push(ip)
      outer_pts.push(op)
    }
    let make_line_edge = fn(a : Vec3, b : Vec3) -> @step.Ref {
      let cpa = ctx.cartesian_point(a.0, a.1, a.2)
      let cpb = ctx.cartesian_point(b.0, b.1, b.2)
      let vpa = ctx.vertex_point(cpa)
      let vpb = ctx.vertex_point(cpb)
      let d = v_norm(v_sub(b, a))
      let dr = ctx.direction(d.0, d.1, d.2)
      ctx.edge_curve(vpa, vpb, ctx.line(cpa, ctx.vector(dr, 1.0)), true)
    }
    let outer_curves : Array[SmoothCurve] = []
    let inner_curves : Array[SmoothCurve] = []
    let outer_edges : Array[@step.Ref] = []
    let inner_edges : Array[@step.Ref] = []
    let bo_edges : Array[@step.Ref] = []
    let oi_edges : Array[@step.Ref] = []
    for j in 0..<strip_count {
      let (oc, oe, _, _, _) = bevel_smooth_curve(ctx, outer_pts[j])
      let (ic, ie, _, _, _) = bevel_smooth_curve(ctx, inner_pts[j])
      outer_curves.push(oc)
      inner_curves.push(ic)
      outer_edges.push(oe)
      inner_edges.push(ie)
      bo_edges.push(make_line_edge(strips[j].back_pts[0], outer_pts[j][0]))
      oi_edges.push(make_line_edge(outer_pts[j][0], inner_pts[j][0]))
    }
    for j in 0..<strip_count {
      let s = strips[j]
      let op = outer_pts[j]
      let p0 = s.back_pts[0]
      let p1 = s.back_pts[1]
      let p2 = op[0]
      let side_expected = v_norm(v_cross(v_sub(p1, p0), v_sub(p2, p0)))
      let (side_surf, _) = bevel_surface(
        ctx,
        s.back_curve,
        outer_curves[j],
        side_expected,
        s.v_deg,
        s.v_mults,
        s.v_knots,
      )
      face_refs.push(
        bevel_face(
          ctx,
          [
            (s.back_edge, true),
            (bo_edges[(j + 1) % strip_count], true),
            (outer_edges[j], false),
            (bo_edges[j], false),
          ],
          side_surf,
          true,
        ),
      )
      let mut sx = 0.0
      let mut sy = 0.0
      for p in s.front_pts {
        sx = sx + p.0
        sy = sy + p.1
      }
      let d = s.front_pts.length().to_double()
      let cr = Double::sqrt(sx / d * (sx / d) + sy / d * (sy / d))
      let band_expected = if cr > CAD_LENGTH_EPS {
        v_norm((sx / d / cr, sy / d / cr, 1.0))
      } else {
        (0.0, 0.0, 1.0)
      }
      let (band_surf, _) = bevel_surface(
        ctx,
        outer_curves[j],
        inner_curves[j],
        band_expected,
        s.v_deg,
        s.v_mults,
        s.v_knots,
      )
      face_refs.push(
        bevel_face(
          ctx,
          [
            (outer_edges[j], true),
            (oi_edges[(j + 1) % strip_count], true),
            (inner_edges[j], false),
            (oi_edges[j], false),
          ],
          band_surf,
          true,
        ),
      )
      front_plane_edges.push(inner_edges[j])
    }
    // Back-cone faces per tooth.
    for k in 0..<num_teeth {
      let patches = patches_per_tooth[k]
      let np = patches.length()
      let cap_loop : Array[(@step.Ref, Bool)] = []
      for i in 0..<np {
        cap_loop.push((patches[np - 1 - i].back_edge, false))
      }
      for patch in patches {
        cap_loop.push((patch.root_edge, true))
      }
      face_refs.push(bevel_face(ctx, cap_loop, cone_ref, true))
    }
  } else {
    // Smooth side surfaces, three strips per tooth, plus one trimmed
    // back-cone face per tooth.
    for k in 0..<num_teeth {
      let patches = patches_per_tooth[k]
      for patch in patches {
        let p0 = local_pts[patch.start_pos]
        let p1 = local_pts[patch.start_pos + 1]
        let p2 = local_pts[front_offset + patch.start_pos]
        let side_expected = v_norm(
          v_cross(
            v_sub(xform.apply(p1), xform.apply(p0)),
            v_sub(xform.apply(p2), xform.apply(p0)),
          ),
        )
        let (side_surf, _) = bevel_surface(
          ctx,
          patch.back_curve,
          patch.front_curve,
          side_expected,
          patch.v_deg,
          patch.v_mults,
          patch.v_knots,
        )
        let (end_edge, end_ori) = find_edge(
          edges,
          patch.end_pos,
          front_offset + patch.end_pos,
        )
        let (start_edge, start_ori) = find_edge(
          edges,
          front_offset + patch.start_pos,
          patch.start_pos,
        )
        face_refs.push(
          bevel_face(
            ctx,
            [
              (patch.back_edge, true),
              (end_edge, end_ori),
              (patch.front_edge, false),
              (start_edge, start_ori),
            ],
            side_surf,
            true,
          ),
        )
      }
      // Tooth-end face on the analytic back cone: the three back edges
      // reversed (shared with the side strips) and the three root arcs
      // forward (shared with the backing plane).
      let np = patches.length()
      let cap_loop : Array[(@step.Ref, Bool)] = []
      for i in 0..<np {
        cap_loop.push((patches[np - 1 - i].back_edge, false))
      }
      for patch in patches {
        cap_loop.push((patch.root_edge, true))
      }
      face_refs.push(bevel_face(ctx, cap_loop, cone_ref, true))
    }
    // Gap root-land side surfaces.
    for k in 0..<num_teeth {
      let end = e.teeth[k].1
      let next_start = e.teeth[(k + 1) % num_teeth].0
      let bc = gap_back_curves[k]
      let fc = gap_front_curves[k]
      let p0 = local_pts[end]
      let p1 = local_pts[(end + 1) % n]
      let p2 = local_pts[front_offset + end]
      let expected = v_norm(
        v_cross(
          v_sub(xform.apply(p1), xform.apply(p0)),
          v_sub(xform.apply(p2), xform.apply(p0)),
        ),
      )
      let (surf, _) = bevel_surface(
        ctx,
        bc,
        fc,
        expected,
        gap_v_deg[k],
        gap_v_mults[k],
        gap_v_knots[k],
      )
      let (start_edge, start_ori) = find_edge(edges, front_offset + end, end)
      let (end_edge, end_ori) = find_edge(
        edges,
        next_start,
        front_offset + next_start,
      )
      face_refs.push(
        bevel_face(
          ctx,
          [
            (gap_back_edges[k], true),
            (end_edge, end_ori),
            (gap_front_edges[k], false),
            (start_edge, start_ori),
          ],
          surf,
          true,
        ),
      )
    }
    // The front cap loop must interleave each tooth's front edges with the
    // following gap edge.
    for k in 0..<num_teeth {
      for patch in patches_per_tooth[k] {
        front_plane_edges.push(patch.front_edge)
      }
      front_plane_edges.push(gap_front_edges[k])
    }
  }

  // Analytic bore between the backing and front planes, when requested.
  let front_holes : Array[@step.Ref] = []
  let back_holes : Array[@step.Ref] = []
  if e.bore_radius_mm > 0.0 {
    let p_b = xform.apply((0.0, 0.0, e.root_z_mm))
    let p_t = xform.apply((0.0, 0.0, e.front_z_mm))
    let cp_b = ctx.cartesian_point(p_b.0, p_b.1, p_b.2)
    let cp_t = ctx.cartesian_point(p_t.0, p_t.1, p_t.2)
    let a2p_b = ctx.axis2_placement_3d(cp_b, dir_up, dir_right)
    let a2p_t = ctx.axis2_placement_3d(cp_t, dir_up, dir_right)
    let radius = @step.fmt_num(e.bore_radius_mm)
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
    let seam_b = xform.apply((e.bore_radius_mm, 0.0, e.root_z_mm))
    let seam_t = xform.apply((e.bore_radius_mm, 0.0, e.front_z_mm))
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
    face_refs.push(
      ctx.advanced_face(
        [ctx.face_outer_bound(lateral_loop, true)],
        cylinder,
        reverse,
      ),
    )
    front_holes.push(
      ctx.face_bound(ctx.edge_loop([ctx.oriented_edge(e_t, false)]), true),
    )
    back_holes.push(
      ctx.face_bound(ctx.edge_loop([ctx.oriented_edge(e_b, true)]), true),
    )
  }

  // Planar front cap bounded by the original front curves or by the inset
  // inner rails of the explicit chamfer band.
  let front_outer = ctx.edge_loop(
    front_plane_edges.map(fn(r) { ctx.oriented_edge(r, true) }),
  )
  let front_plane = smooth_cap_plane(
    ctx,
    up,
    xform.apply((0.0, 0.0, e.front_z_mm)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  let front_bounds : Array[@step.Ref] = [
    ctx.face_outer_bound(front_outer, true),
  ]
  front_bounds.push_iter(front_holes.iter())
  face_refs.push(ctx.advanced_face(front_bounds, front_plane, true))

  // Planar backing cap bounded by the root arcs and gap root curves.
  let back_loop_edges : Array[@step.Ref] = []
  for k in 0..<num_teeth {
    for patch in patches_per_tooth[k] {
      back_loop_edges.push(patch.root_edge)
    }
    back_loop_edges.push(gap_back_edges[k])
  }
  let back_outer = ctx.edge_loop(
    back_loop_edges.rev().map(fn(r) { ctx.oriented_edge(r, false) }),
  )
  let back_plane = smooth_cap_plane(
    ctx,
    down,
    xform.apply((0.0, 0.0, e.root_z_mm)),
    xform.apply_dir((1.0, 0.0, 0.0)),
  )
  let back_bounds : Array[@step.Ref] = [ctx.face_outer_bound(back_outer, true)]
  back_bounds.push_iter(back_holes.iter())
  face_refs.push(ctx.advanced_face(back_bounds, back_plane, true))
  face_refs
}
