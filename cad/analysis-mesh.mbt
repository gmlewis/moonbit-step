///|
/// an_extruded_mesh builds a visualization mesh for an extruded polygon. The
/// caps are fan-triangulated; holes are represented by their side walls. This
/// is an OBJ/visualization helper, not an analytic result.
fn an_extruded_mesh(e : ExtrudedProfile) -> (Array[Vec3], Array[Array[Int32]]) {
  let verts : Array[Vec3] = []
  let faces : Array[Array[Int32]] = []
  let h = e.height_mm
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
      verts.push((p.0, p.1, h))
    }
    for i in 0..<n {
      let j = (i + 1) % n
      faces.push([base + i, base + j, base + n + j, base + n + i])
    }
    // Fan caps for each loop (outer and holes are independent fans).
    for i in 1..<(n - 1) {
      faces.push([base, base + i + 1, base + i])
      faces.push([base + n, base + n + i, base + n + i + 1])
    }
  }
  match e.round_bore {
    Some((center, diameter)) => {
      let rb = diameter / 2.0
      let k = 32
      let base = verts.length()
      for i in 0..<k {
        let th = 2.0 * @math.PI * i.to_double() / k.to_double()
        let x = center.0 + rb * @math.cos(th)
        let y = center.1 + rb * @math.sin(th)
        verts.push((x, y, 0.0))
        verts.push((x, y, h))
      }
      for i in 0..<k {
        let j = (i + 1) % k
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
/// Shape::analysis_mesh returns a triangle/quad visualization mesh in the
/// shape's local frame. It is deliberately separate from the analytic API:
/// mesh output is a graphic approximation.
pub fn Shape::analysis_mesh(
  self : Shape,
) -> Result[(Array[Vec3], Array[Array[Int32]]), AnalysisError] {
  match self {
    Cuboid(c) => {
      let (sx, sy, sz) = (c.sx, c.sy, c.sz)
      let verts : Array[Vec3] = [
        (0.0, 0.0, 0.0),
        (sx, 0.0, 0.0),
        (sx, sy, 0.0),
        (0.0, sy, 0.0),
        (0.0, 0.0, sz),
        (sx, 0.0, sz),
        (sx, sy, sz),
        (0.0, sy, sz),
      ]
      let faces : Array[Array[Int32]] = [
        [0, 3, 2, 1],
        [4, 5, 6, 7],
        [0, 1, 5, 4],
        [1, 2, 6, 5],
        [2, 3, 7, 6],
        [3, 0, 4, 7],
      ]
      Ok((verts, faces))
    }
    Cylinder(c) => {
      let r = c.diameter / 2.0
      let h = c.height
      let k = 48
      let verts : Array[Vec3] = []
      for i in 0..<k {
        let th = 2.0 * @math.PI * i.to_double() / k.to_double()
        verts.push((r * @math.cos(th), r * @math.sin(th), 0.0))
      }
      for i in 0..<k {
        let th = 2.0 * @math.PI * i.to_double() / k.to_double()
        verts.push((r * @math.cos(th), r * @math.sin(th), h))
      }
      let faces : Array[Array[Int32]] = []
      for i in 0..<k {
        let j = (i + 1) % k
        faces.push([i, j, k + j, k + i])
      }
      for i in 1..<(k - 1) {
        faces.push([0, i + 1, i])
        faces.push([k, k + i, k + i + 1])
      }
      Ok((verts, faces))
    }
    RevolvedProfile(rev) => Ok(rev_mesh(rev))
    ToroidalBend(b) =>
      if !b.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(toroidal_bend_mesh(b))
      }
    PipeJunction(j) =>
      if !j.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(pipe_junction_mesh(j))
      }
    SocketedSolid(s) => Ok(socketed_solid_mesh(s))
    ConicalNut(n) => Ok(conical_nut_mesh(n))
    AcornNut(n) => Ok(acorn_nut_mesh(n))
    SquareNut(n) => Ok(square_nut_mesh(n))
    SlitTube(t) => Ok(slit_tube_mesh(t))
    ChamferedPrism(p) => Ok(chamfered_prism_mesh(p))
    ExtrudedProfile(e) =>
      if e.height_mm <= 0.0 || e.profile.outer.length() < 3 {
        Err(DegenerateProfile)
      } else {
        Ok(an_extruded_mesh(e))
      }
    ConicalExtrusion(e) =>
      if e.height_mm <= 0.0 ||
        e.apex_distance_mm <= e.height_mm ||
        e.profile.outer.length() < 3 {
        Err(DegenerateProfile)
      } else {
        Ok(an_conical_mesh(e))
      }
    BevelGearBody(_) =>
      Err(NotAnalytic("back-cone bevel body requires tessellation"))
    ExtrudedArcProfile(e) =>
      if !e.validate() {
        Err(DegenerateProfile)
      } else {
        Ok(extruded_arc_mesh(e))
      }
    SquareHoleWasher(w) =>
      if shw_area(w) <= 0.0 || w.thickness_mm <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(square_hole_mesh(w))
      }
    TabWasher(w) => {
      let (material, _c) = tw_area_centroid(w)
      if material <= 0.0 || w.thickness_mm <= 0.0 {
        Err(DegenerateProfile)
      } else {
        Ok(tab_washer_mesh(w))
      }
    }
    HexHeadWasherFace(h) =>
      match hhwf_proxy(h) {
        Some(p) => Ok(chamfered_prism_mesh(p))
        None => Err(DegenerateProfile)
      }
    Union(u) => {
      let verts : Array[Vec3] = []
      let faces : Array[Array[Int32]] = []
      for child in u.nodes {
        let (cv, cf) = match child.shape.analysis_mesh() {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let base = verts.length()
        for v in cv {
          let (rx, ry, rz) = rotate_point(v, child.rx, child.ry, child.rz)
          verts.push((rx + child.tx, ry + child.ty, rz + child.tz))
        }
        for f in cf {
          faces.push(f.map(fn(idx) { idx + base }))
        }
      }
      Ok((verts, faces))
    }
    ExtrudedBezierProfile(_) =>
      Err(NotAnalytic("mesh requires Bezier tessellation"))
    SweptProfile(_) => Err(NotAnalytic("mesh requires sweep tessellation"))
    Fillet(_) => Err(NotAnalytic("mesh requires a trimming kernel"))
    Chamfer(_) => Err(NotAnalytic("mesh requires a trimming kernel"))
    CalibrationChamferBlock(_) =>
      Err(NotAnalytic("mesh is not implemented for the calibration block"))
    ImportedStep(_) =>
      Err(NotAnalytic("imported STEP meshes come from the source file"))
    Difference(_) => Err(NotAnalytic("nominal difference has no trimmed mesh"))
  }
}

///|
/// Shape::section_at_world_z applies a rigid placement and returns an exact
/// world-z section. Only translations and rotations that preserve +Z are
/// exact; any other rotation returns `UnsupportedTransform` instead of a
/// silently approximate section.
pub fn Shape::section_at_world_z(
  self : Shape,
  rot : Matrix3x3,
  trans : Vec3,
  z : Double,
) -> Result[Section, AnalysisError] {
  let z_preserved = rot.m02.abs() < @step.TOL_1E7 &&
    rot.m12.abs() < @step.TOL_1E7 &&
    (rot.m22 - 1.0).abs() < @step.TOL_1E7
  if !z_preserved {
    return Err(UnsupportedTransform("rotation does not map +Z to +Z"))
  }
  let local_z = z - trans.2
  match self.section_at_local(local_z) {
    Ok(s) =>
      Ok({
        z_mm: z,
        area_mm2: s.area_mm2,
        perimeter_mm: s.perimeter_mm,
        outer_radius_mm: s.outer_radius_mm,
        inner_radius_mm: s.inner_radius_mm,
        rings: s.rings,
      })
    Err(e) => Err(e)
  }
}
