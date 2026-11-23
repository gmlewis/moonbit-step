///|
pub fn Shape::bounding_box(
  self : Shape,
) -> (Double, Double, Double, Double, Double, Double) {
  match self {
    Cuboid(c) => (0.0, c.sx, 0.0, c.sy, 0.0, c.sz)
    Cylinder(c) => {
      let r = c.diameter / 2.0
      (-r, r, -r, r, 0.0, c.height)
    }
    ToroidalBend(b) => b.bounding_box()
    PipeJunction(j) => j.bounding_box()
    RevolvedProfile(rev) => {
      let samples : Array[Vec2] = []
      for seg in rev.segments {
        match seg {
          RevLine(a, b) => {
            samples.push(a)
            samples.push(b)
          }
          RevArc(a, b, c) => {
            // Sample the arc so its extreme radius and height are captured.
            let rho = rev_dist2(a, c)
            let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
            let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
            let delta = rev_norm_angle(a1 - a0)
            let count = 64
            for i in 0..<=count {
              let t = i.to_double() / count.to_double()
              let ang = a0 + delta * t
              samples.push(
                (c.0 + rho * @math.cos(ang), c.1 + rho * @math.sin(ang)),
              )
            }
          }
        }
      }
      let mut r_max = 0.0
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for p in samples {
        if p.0 > r_max {
          r_max = p.0
        }
        if p.1 < z0 {
          z0 = p.1
        }
        if p.1 > z1 {
          z1 = p.1
        }
      }
      if r_max <= 0.0 {
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      } else {
        (-r_max, r_max, -r_max, r_max, z0, z1)
      }
    }
    ChamferedPrism(p) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for level in p.levels {
        let (z, inset) = level
        let ring = match chamfer_inset(p.base, inset) {
          Some(r) => r
          None => p.base
        }
        for pt in ring {
          if pt.0 < x0 {
            x0 = pt.0
          }
          if pt.0 > x1 {
            x1 = pt.0
          }
          if pt.1 < y0 {
            y0 = pt.1
          }
          if pt.1 > y1 {
            y1 = pt.1
          }
        }
        if z < z0 {
          z0 = z
        }
        if z > z1 {
          z1 = z
        }
      }
      (x0, x1, y0, y1, z0, z1)
    }
    SocketedSolid(s) => Shape::RevolvedProfile(s.body).bounding_box()
    ConicalNut(n) => conical_nut_bounding_box(n)
    SlitTube(t) => {
      let r = t.outer_diameter_mm / 2.0
      (-r, r, -r, r, 0.0, t.length_mm)
    }
    AcornNut(n) => acorn_nut_bounding_box(n)
    SquareNut(n) => square_nut_bounding_box(n)
    CalibrationChamferBlock(b) =>
      (0.0, b.length_mm, 0.0, b.width_mm, 0.0, b.height_mm)
    ExtrudedProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for pt in e.profile.outer {
        if pt.0 < x0 {
          x0 = pt.0
        }
        if pt.0 > x1 {
          x1 = pt.0
        }
        if pt.1 < y0 {
          y0 = pt.1
        }
        if pt.1 > y1 {
          y1 = pt.1
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    ConicalExtrusion(e) => {
      // Scaling toward an on-axis apex moves every point closer to the origin,
      // so the large end at z = 0 carries the planar extrema.
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for pt in e.profile.outer {
        if pt.0 < x0 {
          x0 = pt.0
        }
        if pt.0 > x1 {
          x1 = pt.0
        }
        if pt.1 < y0 {
          y0 = pt.1
        }
        if pt.1 > y1 {
          y1 = pt.1
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    BevelGearBody(b) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for p in b.back {
        if p.0 < x0 {
          x0 = p.0
        }
        if p.0 > x1 {
          x1 = p.0
        }
        if p.1 < y0 {
          y0 = p.1
        }
        if p.1 > y1 {
          y1 = p.1
        }
      }
      for p in b.front {
        if p.0 < x0 {
          x0 = p.0
        }
        if p.0 > x1 {
          x1 = p.0
        }
        if p.1 < y0 {
          y0 = p.1
        }
        if p.1 > y1 {
          y1 = p.1
        }
      }
      (x0, x1, y0, y1, b.root_z_mm, b.front_z_mm)
    }
    ExtrudedArcProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for seg in e.segments {
        match seg {
          SegmentLine(a, b) =>
            for pt in [a, b] {
              if pt.0 < x0 {
                x0 = pt.0
              }
              if pt.0 > x1 {
                x1 = pt.0
              }
              if pt.1 < y0 {
                y0 = pt.1
              }
              if pt.1 > y1 {
                y1 = pt.1
              }
            }
          SegmentArc(a, b, c) => {
            let rho = arc_dist2(a, c)
            let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
            let delta = arc_norm_sweep(@math.atan2(b.1 - c.1, b.0 - c.0) - a0)
            for k in 0..<=64 {
              let t = k.to_double() / 64.0
              let ang = a0 + delta * t
              let px = c.0 + rho * @math.cos(ang)
              let py = c.1 + rho * @math.sin(ang)
              if px < x0 {
                x0 = px
              }
              if px > x1 {
                x1 = px
              }
              if py < y0 {
                y0 = py
              }
              if py > y1 {
                y1 = py
              }
            }
            // Axis extrema occur at the cardinal angles; include them exactly
            // rather than relying on the uniform samples to land on them.
            for base in [0.0, @math.PI / 2.0, @math.PI, 3.0 * @math.PI / 2.0] {
              for shift in -1..<=2 {
                let ang = base + 2.0 * @math.PI * shift.to_double()
                if ang >= a0 - CAD_ANGLE_EPS &&
                  ang <= a0 + delta + CAD_ANGLE_EPS {
                  let px = c.0 + rho * @math.cos(ang)
                  let py = c.1 + rho * @math.sin(ang)
                  if px < x0 {
                    x0 = px
                  }
                  if px > x1 {
                    x1 = px
                  }
                  if py < y0 {
                    y0 = py
                  }
                  if py > y1 {
                    y1 = py
                  }
                }
              }
            }
          }
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    SquareHoleWasher(w) => {
      let r = w.outer_diameter_mm / 2.0
      (-r, r, -r, r, 0.0, w.thickness_mm)
    }
    TabWasher(w) => {
      let r = w.outer_diameter_mm / 2.0
      (-w.tab_length_mm, r, -r, r, 0.0, w.thickness_mm)
    }
    HexHeadWasherFace(h) => {
      let r = h.across_flats_mm / Double::sqrt(3.0)
      let z0 = if h.shank_diameter_mm > 0.0 && h.shank_length_mm > 0.0 {
        -h.shank_length_mm
      } else {
        0.0
      }
      (-r, r, -r, r, z0, h.head_height_mm)
    }
    ExtrudedBezierProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for path in e.paths {
        for anchor in path.anchors {
          // Check position and handles for bounding box
          for pt in [anchor.position, anchor.handle_in, anchor.handle_out] {
            if pt.0 < x0 {
              x0 = pt.0
            }
            if pt.0 > x1 {
              x1 = pt.0
            }
            if pt.1 < y0 {
              y0 = pt.1
            }
            if pt.1 > y1 {
              y1 = pt.1
            }
          }
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    Difference(d) => d.base.bounding_box()
    Fillet(f) => f.base.bounding_box()
    Chamfer(c) => c.base.bounding_box()
    ImportedStep(i) => i.bounding_box()
    SweptProfile(s) => {
      // Sweep the actual profile vertices through the same frames the STEP
      // compiler uses. The old implementation expanded the path bounding box by
      // a fixed 5 mm, which made collision checks and component sizes
      // needlessly conservative (a thread or spring appeared 5 mm larger in
      // every direction).
      let path = s.path
      let profile = s.profile
      let n_path = path.points.length()
      if n_path == 0 || profile.vertices.length() < 3 {
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      } else {
        // Profile-local frame: X = right_dir, Z = normal_dir, Y = Z x X.
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
        let loops : Array[Array[Vec3]] = [
          profile.vertices,
          ..profile.holes.filter(fn(h) { h.length() >= 3 }),
        ]
        let local_verts : Array[Vec3] = []
        let is_hole : Array[Bool] = []
        let mut loop_index = 0
        for lp in loops {
          for v in lp {
            local_verts.push(
              apply_matrix(m_global_to_prof, v_sub(v, profile.center)),
            )
            is_hole.push(loop_index > 0)
          }
          loop_index = loop_index + 1
        }
        // First path frame, used by straight outlines and straight holes.
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
        let mut x0 = @double.max_value
        let mut x1 = @double.min_value
        let mut y0 = @double.max_value
        let mut y1 = @double.min_value
        let mut z0 = @double.max_value
        let mut z1 = @double.min_value
        for i in 0..<n_path {
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
            let px = gv.0 + p_origin.0
            let py = gv.1 + p_origin.1
            let pz = gv.2 + p_origin.2
            if px < x0 {
              x0 = px
            }
            if px > x1 {
              x1 = px
            }
            if py < y0 {
              y0 = py
            }
            if py > y1 {
              y1 = py
            }
            if pz < z0 {
              z0 = pz
            }
            if pz > z1 {
              z1 = pz
            }
          }
        }
        (x0, x1, y0, y1, z0, z1)
      }
    }
    Union(u) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for child in u.nodes {
        let (cx0, cx1, cy0, cy1, cz0, cz1) = child.bounding_box()
        if cx0 < x0 {
          x0 = cx0
        }
        if cx1 > x1 {
          x1 = cx1
        }
        if cy0 < y0 {
          y0 = cy0
        }
        if cy1 > y1 {
          y1 = cy1
        }
        if cz0 < z0 {
          z0 = cz0
        }
        if cz1 > z1 {
          z1 = cz1
        }
      }
      (x0, x1, y0, y1, z0, z1)
    }
  }
}

///|
pub fn SceneNode::bounding_box(
  self : SceneNode,
) -> (Double, Double, Double, Double, Double, Double) {
  let (lx0, lx1, ly0, ly1, lz0, lz1) = self.shape.bounding_box()
  let corners = [
    (lx0, ly0, lz0),
    (lx1, ly0, lz0),
    (lx1, ly1, lz0),
    (lx0, ly1, lz0),
    (lx0, ly0, lz1),
    (lx1, ly0, lz1),
    (lx1, ly1, lz1),
    (lx0, ly1, lz1),
  ]
  let mut x0 = @double.max_value
  let mut x1 = @double.min_value
  let mut y0 = @double.max_value
  let mut y1 = @double.min_value
  let mut z0 = @double.max_value
  let mut z1 = @double.min_value
  for p in corners {
    let (tx, ty, tz) = rotate_point(p, self.rx, self.ry, self.rz)
    let gx = tx + self.tx
    let gy = ty + self.ty
    let gz = tz + self.tz
    if gx < x0 {
      x0 = gx
    }
    if gx > x1 {
      x1 = gx
    }
    if gy < y0 {
      y0 = gy
    }
    if gy > y1 {
      y1 = gy
    }
    if gz < z0 {
      z0 = gz
    }
    if gz > z1 {
      z1 = gz
    }
  }
  (x0, x1, y0, y1, z0, z1)
}
