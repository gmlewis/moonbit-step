///|
// Builder-style CAD helpers.
//
// The goal is a pleasant authoring UX for examples: build a model using a few
// high-level calls, then serialize to a valid STEP Part 21 file.

pub struct Rgb {
  r : Double
  g : Double
  b : Double
}

///|
pub struct Design {
  repo : @repository.Repository
  next_solid_id : Int
}

///|
// A 2D profile for extrusion.
//
// - `outer` is the outer boundary loop.
// - `holes` are inner loops (voids).
//
// Loops are expected to be simple, closed polygons without repeating the first
// point at the end.
pub struct Profile2D {
  outer : Array[(Double, Double)]
  holes : Array[Array[(Double, Double)]]
}

///|
// High-level shape handle.
//
// This is intentionally *not* a STEP entity. It captures user intent (e.g. "a
// cube of edge 20mm translated by (x,y,z)") and is later compiled into STEP
// entities inside `Design::add`.
pub enum Solid {
  Cube(Double, String, Rgb, Double, Double, Double)
  // A rectangular block with a swept top-edge profile used for print calibration.
  //
  // - If fillet_radius_mm > 0, we approximate a fillet by stepping multiple
  //   inset rectangles near the top.
  // - Else if chamfer_size_mm > 0, we do a single chamfer (inset) near the top.
  // - Else it is a plain rectangular block.
  //
  // Stored as high-level intent and compiled into STEP entities inside Design::add.
  CalibrationChamferBlock(
    Double,
    Double,
    Double,
    Double,
    Double,
    Int,
    String,
    Rgb,
    Double,
    Double,
    Double
  )

  // A straight extrusion of a 2D profile (optionally with holes) along +Z.
  // Stored as high-level intent and compiled into STEP entities inside Design::add.
  ExtrudedProfile(Profile2D, Double, String, Rgb, Double, Double, Double)
}

///|
pub fn Solid::cube(
  edge_mm : Double,
  name? : String = "cube",
  color? : Rgb = Rgb::{ r: 1.0, g: 0.6, b: 0.0 },
) -> Solid {
  Cube(edge_mm, name, color, 0.0, 0.0, 0.0)
}

///|
// Builder: a print-tuning block that sweeps a top-edge chamfer/fillet profile.
//
// Units are millimeters.
pub fn Solid::calibration_chamfer_block(
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  chamfer_size_mm? : Double = 1.0,
  fillet_radius_mm? : Double = 0.0,
  fillet_segments? : Int = 8,
  name? : String = "calibration-chamfer-block",
  color? : Rgb = Rgb::{ r: 0.2, g: 0.6, b: 1.0 },
) -> Solid {
  CalibrationChamferBlock(
    length_mm, width_mm, height_mm, chamfer_size_mm, fillet_radius_mm, fillet_segments,
    name, color, 0.0, 0.0, 0.0,
  )
}

///|
// Builder: extrude a 2D profile (optionally with holes) into a prismatic solid.
//
// Units are millimeters.
pub fn Solid::extruded_profile(
  outer : Array[(Double, Double)],
  height_mm : Double,
  holes? : Array[Array[(Double, Double)]] = [],
  name? : String = "extruded-profile",
  color? : Rgb = Rgb::{ r: 0.2, g: 0.2, b: 0.2 },
) -> Solid {
  ExtrudedProfile(
    Profile2D::{ outer, holes },
    height_mm,
    name,
    color,
    0.0,
    0.0,
    0.0,
  )
}

///|
pub fn Solid::translate(
  self : Solid,
  x? : Double = 0.0,
  y? : Double = 0.0,
  z? : Double = 0.0,
) -> Solid {
  match self {
    Cube(edge_mm, name, color, tx, ty, tz) =>
      Cube(edge_mm, name, color, tx + x, ty + y, tz + z)
    CalibrationChamferBlock(
      length_mm,
      width_mm,
      height_mm,
      chamfer_size_mm,
      fillet_radius_mm,
      fillet_segments,
      name,
      color,
      tx,
      ty,
      tz
    ) =>
      CalibrationChamferBlock(
        length_mm,
        width_mm,
        height_mm,
        chamfer_size_mm,
        fillet_radius_mm,
        fillet_segments,
        name,
        color,
        tx + x,
        ty + y,
        tz + z,
      )
    ExtrudedProfile(profile, height_mm, name, color, tx, ty, tz) =>
      ExtrudedProfile(profile, height_mm, name, color, tx + x, ty + y, tz + z)
  }
}

///|
fn v_sub(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> (Double, Double, Double) {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ax - bx, ay - by, az - bz)
}

///|
fn v_cross(
  a : (Double, Double, Double),
  b : (Double, Double, Double),
) -> (Double, Double, Double) {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  (ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx)
}

///|
fn v_dot(a : (Double, Double, Double), b : (Double, Double, Double)) -> Double {
  let (ax, ay, az) = a
  let (bx, by, bz) = b
  ax * bx + ay * by + az * bz
}

///|
fn v_len(a : (Double, Double, Double)) -> Double {
  let (x, y, z) = a
  Double::sqrt(x * x + y * y + z * z)
}

///|
fn v_norm(a : (Double, Double, Double)) -> (Double, Double, Double) {
  let l = v_len(a)
  if l == 0.0 {
    (1.0, 0.0, 0.0)
  } else {
    let (x, y, z) = a
    (x / l, y / l, z / l)
  }
}

///|
fn reverse_cycle(verts : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  let mut i = verts.length() - 1
  while i >= 0 {
    out.push(verts[i])
    if i == 0 {
      break
    }
    i = i - 1
  }
  out
}

///|
fn cycle_area_xy(
  pts : Array[(Double, Double, Double)],
  cycle : Array[Int],
) -> Double {
  let n = cycle.length()
  if n < 3 {
    return 0.0
  }
  let mut a = 0.0
  for i = 0; i < n; i = i + 1 {
    let j = (i + 1) % n
    let (xi, yi, _zi) = pts[cycle[i]]
    let (xj, yj, _zj) = pts[cycle[j]]
    a = a + (xi * yj - xj * yi)
  }
  a
}

///|
fn add_plane_face_with_holes_oriented(
  repo : @repository.Repository,
  edges : Array[EdgeInfo],
  pts : Array[(Double, Double, Double)],
  cp_refs : Array[@step.Ref],
  outer_cycle_in : Array[Int],
  hole_cycles_in : Array[Array[Int]],
  expected_out : (Double, Double, Double),
) -> (@repository.Repository, @step.Ref) {
  // Orient outer cycle to ensure outward normal.
  let a0 = outer_cycle_in[0]
  let a1 = outer_cycle_in[1]
  let a2 = outer_cycle_in[2]
  let p0 = pts[a0]
  let p1 = pts[a1]
  let p2 = pts[a2]
  let n = v_cross(v_sub(p1, p0), v_sub(p2, p0))
  let outer_cycle = if v_dot(n, expected_out) < 0.0 {
    reverse_cycle(outer_cycle_in)
  } else {
    outer_cycle_in
  }

  // Ensure holes are oriented opposite to the outer loop.
  let outer_area = cycle_area_xy(pts, outer_cycle)
  let hole_cycles : Array[Array[Int]] = []
  for i = 0; i < hole_cycles_in.length(); i = i + 1 {
    let hc = hole_cycles_in[i]
    let ha = cycle_area_xy(pts, hc)
    if (outer_area >= 0.0 && ha >= 0.0) || (outer_area < 0.0 && ha < 0.0) {
      hole_cycles.push(reverse_cycle(hc))
    } else {
      hole_cycles.push(hc)
    }
  }

  // Plane axes derived from the oriented outer cycle.
  let b0 = outer_cycle[0]
  let b1 = outer_cycle[1]
  let q0 = pts[b0]
  let q1 = pts[b1]
  let q2 = pts[outer_cycle[2]]
  let axis = v_norm(v_cross(v_sub(q1, q0), v_sub(q2, q0)))
  let refd = v_norm(v_sub(q1, q0))
  let mut repo = repo
  let (rN, _idN, axis_ref) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [axis.0, axis.1, axis.2]),
    ),
  )
  repo = rN
  let (rR, _idR, ref_ref) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [refd.0, refd.1, refd.2]),
    ),
  )
  repo = rR
  let a2p = @geometry.Axis2Placement3D::new(
    "",
    cp_refs[outer_cycle[0]],
    axis_ref,
    ref_ref,
  )
  let (rA, _idA, a2p_ref) = add(
    repo,
    @repository.any_entity_axis2_placement_3d(a2p),
  )
  repo = rA
  let plane = @geometry.Plane::new("", a2p_ref)
  let (rP, _idP, plane_ref) = add(repo, @repository.any_entity_plane(plane))
  repo = rP

  // Bounds: one outer + N holes.
  let (rL0, outer_loop_ref) = face_loop(repo, edges, outer_cycle)
  repo = rL0
  let fob = @topology.FaceOuterBound::new("", outer_loop_ref, true)
  let (rB0, _idB0, fob_ref) = add(
    repo,
    @repository.any_entity_face_outer_bound(fob),
  )
  repo = rB0
  let bounds : Array[@step.Ref] = [fob_ref]
  for i = 0; i < hole_cycles.length(); i = i + 1 {
    let (rLi, loop_ref) = face_loop(repo, edges, hole_cycles[i])
    repo = rLi
    let fb = @topology.FaceBound::new("", loop_ref, true)
    let (rBi, _idBi, fb_ref) = add(repo, @repository.any_entity_face_bound(fb))
    repo = rBi
    bounds.push(fb_ref)
  }
  let face = @topology.AdvancedFace::new("", bounds, plane_ref, true)
  let (rF, _idF, face_ref) = add(
    repo,
    @repository.any_entity_advanced_face(face),
  )
  (rF, face_ref)
}

///|
fn add_plane_face_oriented(
  repo : @repository.Repository,
  edges : Array[EdgeInfo],
  pts : Array[(Double, Double, Double)],
  cp_refs : Array[@step.Ref],
  verts_cycle : Array[Int],
  expected_out : (Double, Double, Double),
) -> (@repository.Repository, @step.Ref) {
  // Ensure face vertex order produces an outward-pointing normal.
  let a0 = verts_cycle[0]
  let a1 = verts_cycle[1]
  let a2 = verts_cycle[2]
  let p0 = pts[a0]
  let p1 = pts[a1]
  let p2 = pts[a2]
  let n = v_cross(v_sub(p1, p0), v_sub(p2, p0))
  let cycle = if v_dot(n, expected_out) < 0.0 {
    reverse_cycle(verts_cycle)
  } else {
    verts_cycle
  }
  let b0 = cycle[0]
  let b1 = cycle[1]
  let q0 = pts[b0]
  let q1 = pts[b1]
  let q2 = pts[cycle[2]]
  let axis = v_norm(v_cross(v_sub(q1, q0), v_sub(q2, q0)))
  let refd = v_norm(v_sub(q1, q0))
  let mut repo = repo
  let (rN, _idN, axis_ref) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [axis.0, axis.1, axis.2]),
    ),
  )
  repo = rN
  let (rR, _idR, ref_ref) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [refd.0, refd.1, refd.2]),
    ),
  )
  repo = rR
  add_plane_face(repo, edges, cycle, cp_refs[cycle[0]], axis_ref, ref_ref)
}

///|
fn add(
  repo : @repository.Repository,
  entity : @repository.AnyEntity,
) -> (@repository.Repository, @step.EntityId, @step.Ref) {
  let (repo, id) = repo.add(entity)
  (repo, id, @step.Ref::{ id, })
}

///|
fn default_header(
  file_name : String,
  description : String,
) -> @header.HeaderSection {
  let timestamp = now_iso_timestamp()
  @header.HeaderSection::new([
    @header.HeaderEntity::FileDescription(
      @header.FileDescription::new([description], "2;1"),
    ),
    @header.HeaderEntity::FileName(
      @header.FileName::new(
        @header.StringOrDollar::Str(file_name),
        @header.StringOrDollar::Str(timestamp),
        @header.StringListOrDollar::List(["gmlewis"]),
        @header.StringListOrDollar::List(["gmlewis/step"]),
        @header.StringOrDollar::Str("gmlewis/step"),
        @header.StringOrDollar::Str("moonbit"),
        @header.StringOrDollar::Str("none"),
      ),
    ),
    @header.HeaderEntity::FileSchema(
      @header.FileSchema::new(["AUTOMOTIVE_DESIGN { 1 0 10303 214 3 1 1 1 }"]),
    ),
  ])
}

///|
fn now_iso_timestamp() -> String {
  // @async.now() returns milliseconds since epoch.
  // We format to second precision because STEP headers typically use
  // `YYYY-MM-DDTHH:MM:SS`.
  let ms = @async.now()
  let seconds = ms / 1000L
  try
    @time.PlainDateTime::from_unix_second(seconds, 0, @time.utc_offset)
  catch {
    _ => "2025-01-01T00:00:00"
  } noraise {
    dt => dt.to_string()
  }
}

///|
pub fn Design::new(
  name? : String = "model",
  description? : String = "generated by gmlewis/step/cad",
) -> Design {
  let file_name = "\{name}.step"
  let mut repo = @repository.new()
  repo = repo.set_header(default_header(file_name, description))
  Design::{ repo, next_solid_id: 1 }
}

///|
pub fn Design::to_step_file(self : Design) -> String {
  self.repo.to_step_file()
}

///|
// Convenience alias for examples that want `println(design.to_string())`.
pub fn Design::to_string(self : Design) -> String {
  self.to_step_file()
}

///|
pub async fn Design::write_step_file(self : Design, out_path : String?) -> Unit {
  write_step_text(self.to_step_file(), out_path)
}

///|
// Convenience alias: `design.write_step(...)`.
pub async fn Design::write_step(self : Design, out_path : String?) -> Unit {
  self.write_step_file(out_path)
}

///|
// Add a high-level solid to the design (builder chaining).
pub fn Design::add(self : Design, solid : Solid) -> Design {
  let instance_id = self.next_solid_id
  let out = match solid {
    Cube(edge_mm, base_name, color, tx, ty, tz) =>
      self.add_cube_at(
        edge_mm,
        "\{base_name}-\{instance_id}",
        color,
        tx,
        ty,
        tz,
      )
    CalibrationChamferBlock(
      length_mm,
      width_mm,
      height_mm,
      chamfer_size_mm,
      fillet_radius_mm,
      fillet_segments,
      base_name,
      color,
      tx,
      ty,
      tz
    ) =>
      self.add_calibration_chamfer_block_at(
        length_mm,
        width_mm,
        height_mm,
        chamfer_size_mm,
        fillet_radius_mm,
        fillet_segments,
        "\{base_name}-\{instance_id}",
        color,
        tx,
        ty,
        tz,
      )
    ExtrudedProfile(profile, height_mm, base_name, color, tx, ty, tz) =>
      self.add_extruded_profile_at(
        profile,
        height_mm,
        "\{base_name}-\{instance_id}",
        color,
        tx,
        ty,
        tz,
      )
  }
  Design::{ repo: out.repo, next_solid_id: instance_id + 1 }
}

///|
fn Design::add_calibration_chamfer_block_at(
  self : Design,
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  chamfer_size_mm : Double,
  fillet_radius_mm : Double,
  fillet_segments : Int,
  name : String,
  _color : Rgb,
  tx : Double,
  ty : Double,
  tz : Double,
) -> Design {
  let mut repo = self.repo

  // Build a stack of inset rectangles (offset) along Z.
  // Base ring at z=0, then a vertical section, then the top-edge profile.
  let l = length_mm
  let w = width_mm
  let h = height_mm
  let rings : Array[(Double, Double)] = []
  rings.push((0.0, 0.0))
  if fillet_radius_mm > 0.0 {
    let r = fillet_radius_mm
    let start_z = h - r
    rings.push((start_z, 0.0))
    let segs = if fillet_segments <= 0 { 8 } else { fillet_segments }
    // Quarter circle profile centered at (offset=r, z=h-r).
    // offset(phi) = r - r*cos(phi)
    // z(phi)      = (h-r) + r*sin(phi)
    let mut i = 1
    while i <= segs {
      let phi = Double::from_int(i) * (@math.PI / 2.0) / Double::from_int(segs)
      let offset = r - r * @math.cos(phi)
      let z = h - r + r * @math.sin(phi)
      rings.push((z, offset))
      i = i + 1
    }
  } else if chamfer_size_mm > 0.0 {
    let c = chamfer_size_mm
    rings.push((h - c, 0.0))
    rings.push((h, c))
  } else {
    rings.push((h, 0.0))
  }

  // Points (mm)
  let pts : Array[(Double, Double, Double)] = []
  for i = 0; i < rings.length(); i = i + 1 {
    let (z, o) = rings[i]
    let z0 = tz + z
    let x0 = tx + o
    let x1 = tx + (l - o)
    let y0 = ty + o
    let y1 = ty + (w - o)
    // Ring vertices in CCW order when viewed from +Z.
    pts.push((x0, y0, z0))
    pts.push((x1, y0, z0))
    pts.push((x1, y1, z0))
    pts.push((x0, y1, z0))
  }

  // Cartesian points
  let cp_refs : Array[@step.Ref] = []
  for i = 0; i < pts.length(); i = i + 1 {
    let (x, y, z) = pts[i]
    let cp = @geometry.CartesianPoint::new("", [x, y, z])
    let (r, _id, cp_ref) = add(repo, @repository.any_entity_cartesian_point(cp))
    repo = r
    cp_refs.push(cp_ref)
  }

  // Vertex points
  let vp_refs : Array[@step.Ref] = []
  for i = 0; i < cp_refs.length(); i = i + 1 {
    let vp = @topology.VertexPoint::new("", cp_refs[i])
    let (r, _id, vp_ref) = add(repo, @repository.any_entity_vertex_point(vp))
    repo = r
    vp_refs.push(vp_ref)
  }

  // Build all unique edges for the ring stack.
  let edge_key = fn(a : Int, b : Int) -> String {
    if a < b {
      "\{a}:\{b}"
    } else {
      "\{b}:\{a}"
    }
  }
  let seen : Map[String, Bool] = Map::new()
  let edges : Array[EdgeInfo] = []
  let add_edge = fn(
    repo_in : @repository.Repository,
    a : Int,
    b : Int,
  ) -> (@repository.Repository, Unit) {
    let mut repo = repo_in
    let k = edge_key(a, b)
    if seen.get(k).unwrap_or(false) {
      return (repo, ())
    }
    seen.set(k, true)
    let start = if a < b { a } else { b }
    let end = if a < b { b } else { a }
    let dir = v_norm(v_sub(pts[end], pts[start]))
    let (rD, _idD, dir_ref) = add(
      repo,
      @repository.any_entity_direction(
        @geometry.Direction::new("", [dir.0, dir.1, dir.2]),
      ),
    )
    repo = rD
    let (rV, _idV, vec_ref) = add(
      repo,
      @repository.any_entity_vector(@geometry.Vector::new("", dir_ref, 1.0)),
    )
    repo = rV
    let line = @geometry.Line::new("", cp_refs[start], vec_ref)
    let (rL, _idL, line_ref) = add(repo, @repository.any_entity_line(line))
    repo = rL
    let ec = @topology.EdgeCurve::new(
      "",
      vp_refs[start],
      vp_refs[end],
      line_ref,
      true,
    )
    let (rE, _idE, ec_ref) = add(repo, @repository.any_entity_edge_curve(ec))
    repo = rE
    edges.push(EdgeInfo::{ start, end, edge: ec_ref })
    (repo, ())
  }

  // Per-ring perimeter edges
  for ri = 0; ri < rings.length(); ri = ri + 1 {
    let base = ri * 4
    let (r0, _) = add_edge(repo, base + 0, base + 1)
    repo = r0
    let (r1, _) = add_edge(repo, base + 1, base + 2)
    repo = r1
    let (r2, _) = add_edge(repo, base + 2, base + 3)
    repo = r2
    let (r3, _) = add_edge(repo, base + 3, base + 0)
    repo = r3
  }

  // Between-ring edges
  for ri = 0; ri + 1 < rings.length(); ri = ri + 1 {
    let a = ri * 4
    let b = (ri + 1) * 4
    let (r0, _) = add_edge(repo, a + 0, b + 0)
    repo = r0
    let (r1, _) = add_edge(repo, a + 1, b + 1)
    repo = r1
    let (r2, _) = add_edge(repo, a + 2, b + 2)
    repo = r2
    let (r3, _) = add_edge(repo, a + 3, b + 3)
    repo = r3
  }

  // Faces
  let face_refs : Array[@step.Ref] = []
  let bottom = [0, 3, 2, 1]
  let (rB, fB) = add_plane_face_oriented(
    repo,
    edges,
    pts,
    cp_refs,
    bottom,
    (0.0, 0.0, -1.0),
  )
  repo = rB
  face_refs.push(fB)
  let top_base = (rings.length() - 1) * 4
  let top = [top_base + 0, top_base + 1, top_base + 2, top_base + 3]
  let (rT, fT) = add_plane_face_oriented(
    repo,
    edges,
    pts,
    cp_refs,
    top,
    (0.0, 0.0, 1.0),
  )
  repo = rT
  face_refs.push(fT)

  // Side faces per ring segment
  for ri = 0; ri + 1 < rings.length(); ri = ri + 1 {
    let a = ri * 4
    let b = (ri + 1) * 4

    // front (-Y)
    let (rF, fF) = add_plane_face_oriented(
      repo,
      edges,
      pts,
      cp_refs,
      [a + 0, a + 1, b + 1, b + 0],
      (0.0, -1.0, 0.0),
    )
    repo = rF
    face_refs.push(fF)

    // right (+X)
    let (rR, fR) = add_plane_face_oriented(
      repo,
      edges,
      pts,
      cp_refs,
      [a + 1, a + 2, b + 2, b + 1],
      (1.0, 0.0, 0.0),
    )
    repo = rR
    face_refs.push(fR)

    // back (+Y)
    let (rBk, fBk) = add_plane_face_oriented(
      repo,
      edges,
      pts,
      cp_refs,
      [a + 2, a + 3, b + 3, b + 2],
      (0.0, 1.0, 0.0),
    )
    repo = rBk
    face_refs.push(fBk)

    // left (-X)
    let (rL, fL) = add_plane_face_oriented(
      repo,
      edges,
      pts,
      cp_refs,
      [a + 3, a + 0, b + 0, b + 3],
      (-1.0, 0.0, 0.0),
    )
    repo = rL
    face_refs.push(fL)
  }
  let shell = @topology.ClosedShell::new("", face_refs)
  let (rS, _idS, shell_ref) = add(
    repo,
    @repository.any_entity_closed_shell(shell),
  )
  repo = rS
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  let (rM, _idM, brep_ref) = add(
    repo,
    @repository.any_entity_manifold_solid_brep(brep),
  )
  repo = rM

  // From here on we reuse the same product/representation boilerplate as the cube.
  // Units + representation context (complex instance)
  let dim_exp = @units.DimensionalExponents::new(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let (rDE, dim_exp_id, _dim_exp_ref) = add(
    repo,
    @repository.any_entity_dimensional_exponents(dim_exp),
  )
  repo = rDE
  let cx_radian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".RADIAN.")),
  ])
  let (r193, _id193, ref193) = add(
    repo,
    @repository.any_entity_complex_instance(cx_radian),
  )
  repo = r193
  let pa_meas = @units.PlaneAngleMeasureWithUnit::new("0.0174532925", ref193)
  let (r192, _id192, ref192) = add(
    repo,
    @repository.any_entity_plane_angle_measure_with_unit(pa_meas),
  )
  repo = r192
  let cx_degree = @context.ComplexInstance::new([
    @context.ComplexPart::ConversionBasedUnit(
      @units.ConversionBasedUnit::new("DEGREE", ref192),
    ),
    @context.ComplexPart::NamedUnit(
      @units.NamedUnit::new("#\{dim_exp_id.value}"),
    ),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
  ])
  let (r190, id190, _ref190) = add(
    repo,
    @repository.any_entity_complex_instance(cx_degree),
  )
  repo = r190
  let cx_steradian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".STERADIAN.")),
    @context.ComplexPart::SolidAngleUnit(@units.SolidAngleUnit::new()),
  ])
  let (r189, id189, _ref189) = add(
    repo,
    @repository.any_entity_complex_instance(cx_steradian),
  )
  repo = r189
  let cx_mm = @context.ComplexInstance::new([
    @context.ComplexPart::LengthUnit(@units.LengthUnit::new()),
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new(".MILLI.", ".METRE.")),
  ])
  let (r194, id194, ref194) = add(
    repo,
    @repository.any_entity_complex_instance(cx_mm),
  )
  repo = r194
  let unc = @units.UncertaintyMeasureWithUnit::new(
    "2.E-005", ref194, "DISTANCE_ACCURACY_VALUE", "Maximum Tolerance applied to model",
  )
  let (r188, id188, _ref188) = add(
    repo,
    @repository.any_entity_uncertainty_measure_with_unit(unc),
  )
  repo = r188
  let cx_ctx = @context.ComplexInstance::new([
    @context.ComplexPart::GeomRepCtx(
      @context.GeometricRepresentationContext::new(3),
    ),
    @context.ComplexPart::GlobUncCtx(
      @context.GlobalUncertaintyAssignedContext::new([id188]),
    ),
    @context.ComplexPart::GlobUnitCtx(
      @context.GlobalUnitAssignedContext::new([id194, id190, id189]),
    ),
    @context.ComplexPart::RepCtx(
      @context.RepresentationContext::new(name, "TOP_LEVEL_ASSEMBLY_PART"),
    ),
  ])
  let (r187, _id187, ref187) = add(
    repo,
    @repository.any_entity_complex_instance(cx_ctx),
  )
  repo = r187

  // Global placement for the shape representation
  let (rDz, _idDz, dz) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, 0.0, 1.0]),
    ),
  )
  repo = rDz
  let (rDx, _idDx, dx) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [1.0, 0.0, 0.0]),
    ),
  )
  repo = rDx
  let a2p_global = @geometry.Axis2Placement3D::new("", cp_refs[0], dz, dx)
  let (rA2, _idA2, a2p_global_ref) = add(
    repo,
    @repository.any_entity_axis2_placement_3d(a2p_global),
  )
  repo = rA2
  let shape_rep = @product.ShapeRepresentation::new(
    "\{name}-None",
    [a2p_global_ref],
    ref187,
  )
  let (r22, _id22, ref22) = add(
    repo,
    @repository.any_entity_shape_representation(shape_rep),
  )
  repo = r22
  let brep_rep = @product.AdvancedBrepShapeRepresentation::new(
    "\{name}-None",
    [brep_ref],
    ref187,
  )
  let (r11, _id11, ref11) = add(
    repo,
    @repository.any_entity_advanced_brep_shape_representation(brep_rep),
  )
  repo = r11
  let rel = @product.ShapeRepresentationRelationship::new(
    "None",
    "relationship between \{name}-None and \{name}-None",
    ref22,
    ref11,
  )
  let (r10, _id10, _ref10) = add(
    repo,
    @repository.any_entity_shape_representation_relationship(rel),
  )
  repo = r10

  // Product structure
  let app_ctx = @product.ApplicationContext::new(
    "core data for automotive mechanical design processes",
  )
  let (r21, _id21, ref21) = add(
    repo,
    @repository.any_entity_application_context(app_ctx),
  )
  repo = r21
  let app_proto = @product.ApplicationProtocolDefinition::new(
    "international standard", "automotive_design", 2010, ref21,
  )
  let (r20, _id20, _ref20) = add(
    repo,
    @repository.any_entity_application_protocol_definition(app_proto),
  )
  repo = r20
  let prod_ctx = @product.ProductContext::new(" ", ref21, "mechanical")
  let (r19, _id19, ref19) = add(
    repo,
    @repository.any_entity_product_context(prod_ctx),
  )
  repo = r19
  let product = @product.Product::new(name, name, " ", [ref19])
  let (r18, _id18, ref18) = add(repo, @repository.any_entity_product(product))
  repo = r18
  let cat = @product.ProductRelatedProductCategory::new("part", "", [ref18])
  let (r17, _id17, _ref17) = add(
    repo,
    @repository.any_entity_product_related_product_category(cat),
  )
  repo = r17
  let form = @product.ProductDefinitionFormationWithSpecifiedSource::new(
    " ", " ", ref18, ".NOT_KNOWN.",
  )
  let (r16, _id16, ref16) = add(
    repo,
    @repository.any_entity_product_definition_formation_with_specified_source(
      form,
    ),
  )
  repo = r16
  let def_ctx = @product.ProductDefinitionContext::new(
    "part definition", ref21, "design",
  )
  let (r15, _id15, ref15) = add(
    repo,
    @repository.any_entity_product_definition_context(def_ctx),
  )
  repo = r15
  let prod_def = @product.ProductDefinition::new(" ", "", ref16, ref15)
  let (r14, _id14, ref14) = add(
    repo,
    @repository.any_entity_product_definition(prod_def),
  )
  repo = r14
  let pds = @product.ProductDefinitionShape::new("", "", ref14)
  let (r13, _id13, ref13) = add(
    repo,
    @repository.any_entity_product_definition_shape(pds),
  )
  repo = r13
  let sdr = @product.ShapeDefinitionRepresentation::new(ref13, ref22)
  let (r12, _id12, _ref12) = add(
    repo,
    @repository.any_entity_shape_definition_representation(sdr),
  )
  repo = r12
  Design::{ repo, next_solid_id: self.next_solid_id }
}

///|
fn Design::add_extruded_profile_at(
  self : Design,
  profile : Profile2D,
  height_mm : Double,
  name : String,
  _color : Rgb,
  tx : Double,
  ty : Double,
  tz : Double,
) -> Design {
  let mut repo = self.repo
  if height_mm == 0.0 || profile.outer.length() < 3 {
    return Design::{ repo, next_solid_id: self.next_solid_id }
  }
  let z0 = tz
  let z1 = tz + height_mm

  // Flatten loops (outer first, then holes).
  let loops : Array[Array[(Double, Double)]] = []
  loops.push(profile.outer)
  for i = 0; i < profile.holes.length(); i = i + 1 {
    if profile.holes[i].length() >= 3 {
      loops.push(profile.holes[i])
    }
  }

  // Build 3D points (bottom then top per loop).
  let pts : Array[(Double, Double, Double)] = []
  let loop_bottom : Array[Array[Int]] = []
  let loop_top : Array[Array[Int]] = []
  for li = 0; li < loops.length(); li = li + 1 {
    let poly = loops[li]
    let b : Array[Int] = []
    let t : Array[Int] = []
    for pi = 0; pi < poly.length(); pi = pi + 1 {
      let (x, y) = poly[pi]
      pts.push((tx + x, ty + y, z0))
      b.push(pts.length() - 1)
    }
    for pi = 0; pi < poly.length(); pi = pi + 1 {
      let (x, y) = poly[pi]
      pts.push((tx + x, ty + y, z1))
      t.push(pts.length() - 1)
    }
    loop_bottom.push(b)
    loop_top.push(t)
  }

  // Cartesian points
  let cp_refs : Array[@step.Ref] = []
  for i = 0; i < pts.length(); i = i + 1 {
    let (x, y, z) = pts[i]
    let cp = @geometry.CartesianPoint::new("", [x, y, z])
    let (r, _id, cp_ref) = add(repo, @repository.any_entity_cartesian_point(cp))
    repo = r
    cp_refs.push(cp_ref)
  }

  // Vertex points
  let vp_refs : Array[@step.Ref] = []
  for i = 0; i < cp_refs.length(); i = i + 1 {
    let vp = @topology.VertexPoint::new("", cp_refs[i])
    let (r, _id, vp_ref) = add(repo, @repository.any_entity_vertex_point(vp))
    repo = r
    vp_refs.push(vp_ref)
  }

  // Unique edges
  let edge_key = fn(a : Int, b : Int) -> String {
    if a < b {
      "\{a}:\{b}"
    } else {
      "\{b}:\{a}"
    }
  }
  let seen : Map[String, Bool] = Map::new()
  let edges : Array[EdgeInfo] = []
  let add_edge = fn(
    repo_in : @repository.Repository,
    a : Int,
    b : Int,
  ) -> @repository.Repository {
    let mut repo = repo_in
    let k = edge_key(a, b)
    if seen.get(k).unwrap_or(false) {
      return repo
    }
    seen.set(k, true)
    let start = if a < b { a } else { b }
    let end = if a < b { b } else { a }
    let dir = v_norm(v_sub(pts[end], pts[start]))
    let (rD, _idD, dir_ref) = add(
      repo,
      @repository.any_entity_direction(
        @geometry.Direction::new("", [dir.0, dir.1, dir.2]),
      ),
    )
    repo = rD
    let (rV, _idV, vec_ref) = add(
      repo,
      @repository.any_entity_vector(@geometry.Vector::new("", dir_ref, 1.0)),
    )
    repo = rV
    let line = @geometry.Line::new("", cp_refs[start], vec_ref)
    let (rL, _idL, line_ref) = add(repo, @repository.any_entity_line(line))
    repo = rL
    let ec = @topology.EdgeCurve::new(
      "",
      vp_refs[start],
      vp_refs[end],
      line_ref,
      true,
    )
    let (rE, _idE, ec_ref) = add(repo, @repository.any_entity_edge_curve(ec))
    repo = rE
    edges.push(EdgeInfo::{ start, end, edge: ec_ref })
    repo
  }

  // Per-loop perimeter + vertical edges
  for li = 0; li < loops.length(); li = li + 1 {
    let b = loop_bottom[li]
    let t = loop_top[li]
    let n = b.length()
    for i = 0; i < n; i = i + 1 {
      let j = (i + 1) % n
      repo = add_edge(repo, b[i], b[j])
      repo = add_edge(repo, t[i], t[j])
      repo = add_edge(repo, b[i], t[i])
    }
  }

  // Faces
  let face_refs : Array[@step.Ref] = []

  // Bottom/top (with holes)
  let outer_b = loop_bottom[0]
  let outer_t = loop_top[0]
  let hole_bs : Array[Array[Int]] = []
  let hole_ts : Array[Array[Int]] = []
  for li = 1; li < loops.length(); li = li + 1 {
    hole_bs.push(loop_bottom[li])
    hole_ts.push(loop_top[li])
  }
  let (rB, fB) = add_plane_face_with_holes_oriented(
    repo,
    edges,
    pts,
    cp_refs,
    outer_b,
    hole_bs,
    (0.0, 0.0, -1.0),
  )
  repo = rB
  face_refs.push(fB)
  let (rT, fT) = add_plane_face_with_holes_oriented(
    repo,
    edges,
    pts,
    cp_refs,
    outer_t,
    hole_ts,
    (0.0, 0.0, 1.0),
  )
  repo = rT
  face_refs.push(fT)

  // Side faces (outer + holes)
  let add_side_faces = fn(
    repo_in : @repository.Repository,
    b : Array[Int],
    t : Array[Int],
  ) -> @repository.Repository {
    let mut repo = repo_in
    let n = b.length()
    for i = 0; i < n; i = i + 1 {
      let j = (i + 1) % n
      let (x0, y0, _z0) = pts[b[i]]
      let (x1, y1, _z1) = pts[b[j]]
      let dx = x1 - x0
      let dy = y1 - y0
      let expected = v_norm((dy, -dx, 0.0))
      let (rF, fF) = add_plane_face_oriented(
        repo,
        edges,
        pts,
        cp_refs,
        [b[i], b[j], t[j], t[i]],
        expected,
      )
      repo = rF
      face_refs.push(fF)
    }
    repo
  }
  repo = add_side_faces(repo, outer_b, outer_t)
  for li = 1; li < loops.length(); li = li + 1 {
    repo = add_side_faces(repo, loop_bottom[li], loop_top[li])
  }

  // Solid
  let shell = @topology.ClosedShell::new("", face_refs)
  let (rS, _idS, shell_ref) = add(
    repo,
    @repository.any_entity_closed_shell(shell),
  )
  repo = rS
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  let (rM, _idM, brep_ref) = add(
    repo,
    @repository.any_entity_manifold_solid_brep(brep),
  )
  repo = rM

  // Reuse the same product/representation boilerplate as the calibration block.
  // Units + representation context (complex instance)
  let dim_exp = @units.DimensionalExponents::new(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let (rDE, dim_exp_id, _dim_exp_ref) = add(
    repo,
    @repository.any_entity_dimensional_exponents(dim_exp),
  )
  repo = rDE
  let cx_radian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".RADIAN.")),
  ])
  let (r193, _id193, ref193) = add(
    repo,
    @repository.any_entity_complex_instance(cx_radian),
  )
  repo = r193
  let pa_meas = @units.PlaneAngleMeasureWithUnit::new("0.0174532925", ref193)
  let (r192, _id192, ref192) = add(
    repo,
    @repository.any_entity_plane_angle_measure_with_unit(pa_meas),
  )
  repo = r192
  let cx_degree = @context.ComplexInstance::new([
    @context.ComplexPart::ConversionBasedUnit(
      @units.ConversionBasedUnit::new("DEGREE", ref192),
    ),
    @context.ComplexPart::NamedUnit(
      @units.NamedUnit::new("#\{dim_exp_id.value}"),
    ),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
  ])
  let (r190, id190, _ref190) = add(
    repo,
    @repository.any_entity_complex_instance(cx_degree),
  )
  repo = r190
  let cx_steradian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".STERADIAN.")),
    @context.ComplexPart::SolidAngleUnit(@units.SolidAngleUnit::new()),
  ])
  let (r189, id189, _ref189) = add(
    repo,
    @repository.any_entity_complex_instance(cx_steradian),
  )
  repo = r189
  let cx_mm = @context.ComplexInstance::new([
    @context.ComplexPart::LengthUnit(@units.LengthUnit::new()),
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new(".MILLI.", ".METRE.")),
  ])
  let (r194, id194, ref194) = add(
    repo,
    @repository.any_entity_complex_instance(cx_mm),
  )
  repo = r194
  let unc = @units.UncertaintyMeasureWithUnit::new(
    "2.E-005", ref194, "DISTANCE_ACCURACY_VALUE", "Maximum Tolerance applied to model",
  )
  let (r188, id188, _ref188) = add(
    repo,
    @repository.any_entity_uncertainty_measure_with_unit(unc),
  )
  repo = r188
  let cx_ctx = @context.ComplexInstance::new([
    @context.ComplexPart::GeomRepCtx(
      @context.GeometricRepresentationContext::new(3),
    ),
    @context.ComplexPart::GlobUncCtx(
      @context.GlobalUncertaintyAssignedContext::new([id188]),
    ),
    @context.ComplexPart::GlobUnitCtx(
      @context.GlobalUnitAssignedContext::new([id194, id190, id189]),
    ),
    @context.ComplexPart::RepCtx(
      @context.RepresentationContext::new(name, "TOP_LEVEL_ASSEMBLY_PART"),
    ),
  ])
  let (r187, _id187, ref187) = add(
    repo,
    @repository.any_entity_complex_instance(cx_ctx),
  )
  repo = r187

  // Global placement for the shape representation
  let (rDz, _idDz, dz) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, 0.0, 1.0]),
    ),
  )
  repo = rDz
  let (rDx, _idDx, dx) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [1.0, 0.0, 0.0]),
    ),
  )
  repo = rDx
  let a2p_global = @geometry.Axis2Placement3D::new("", cp_refs[0], dz, dx)
  let (rA2, _idA2, a2p_global_ref) = add(
    repo,
    @repository.any_entity_axis2_placement_3d(a2p_global),
  )
  repo = rA2
  let shape_rep = @product.ShapeRepresentation::new(
    "\{name}-None",
    [a2p_global_ref],
    ref187,
  )
  let (r22, _id22, ref22) = add(
    repo,
    @repository.any_entity_shape_representation(shape_rep),
  )
  repo = r22
  let brep_rep = @product.AdvancedBrepShapeRepresentation::new(
    "\{name}-None",
    [brep_ref],
    ref187,
  )
  let (r11, _id11, ref11) = add(
    repo,
    @repository.any_entity_advanced_brep_shape_representation(brep_rep),
  )
  repo = r11
  let rel = @product.ShapeRepresentationRelationship::new(
    "None",
    "relationship between \{name}-None and \{name}-None",
    ref22,
    ref11,
  )
  let (r10, _id10, _ref10) = add(
    repo,
    @repository.any_entity_shape_representation_relationship(rel),
  )
  repo = r10

  // Product structure
  let app_ctx = @product.ApplicationContext::new(
    "core data for automotive mechanical design processes",
  )
  let (r21, _id21, ref21) = add(
    repo,
    @repository.any_entity_application_context(app_ctx),
  )
  repo = r21
  let app_proto = @product.ApplicationProtocolDefinition::new(
    "international standard", "automotive_design", 2010, ref21,
  )
  let (r20, _id20, _ref20) = add(
    repo,
    @repository.any_entity_application_protocol_definition(app_proto),
  )
  repo = r20
  let prod_ctx = @product.ProductContext::new(" ", ref21, "mechanical")
  let (r19, _id19, ref19) = add(
    repo,
    @repository.any_entity_product_context(prod_ctx),
  )
  repo = r19
  let product = @product.Product::new(name, name, " ", [ref19])
  let (r18, _id18, ref18) = add(repo, @repository.any_entity_product(product))
  repo = r18
  let cat = @product.ProductRelatedProductCategory::new("part", "", [ref18])
  let (r17, _id17, _ref17) = add(
    repo,
    @repository.any_entity_product_related_product_category(cat),
  )
  repo = r17
  let form = @product.ProductDefinitionFormationWithSpecifiedSource::new(
    " ", " ", ref18, ".NOT_KNOWN.",
  )
  let (r16, _id16, ref16) = add(
    repo,
    @repository.any_entity_product_definition_formation_with_specified_source(
      form,
    ),
  )
  repo = r16
  let def_ctx = @product.ProductDefinitionContext::new(
    "part definition", ref21, "design",
  )
  let (r15, _id15, ref15) = add(
    repo,
    @repository.any_entity_product_definition_context(def_ctx),
  )
  repo = r15
  let prod_def = @product.ProductDefinition::new(" ", "", ref16, ref15)
  let (r14, _id14, ref14) = add(
    repo,
    @repository.any_entity_product_definition(prod_def),
  )
  repo = r14
  let pds = @product.ProductDefinitionShape::new("", "", ref14)
  let (r13, _id13, ref13) = add(
    repo,
    @repository.any_entity_product_definition_shape(pds),
  )
  repo = r13
  let sdr = @product.ShapeDefinitionRepresentation::new(ref13, ref22)
  let (r12, _id12, _ref12) = add(
    repo,
    @repository.any_entity_shape_definition_representation(sdr),
  )
  repo = r12
  Design::{ repo, next_solid_id: self.next_solid_id }
}

///|
pub async fn write_step_text(step_text : String, out_path : String?) -> Unit {
  match out_path {
    None => println(step_text)
    Some(path) =>
      @fs.write_file(
        path,
        @encoding/utf8.encode(step_text),
        create=0o644,
        truncate=true,
      ) catch {
        err => println("failed to write output: \{err}")
      }
  }
}

///|
priv struct EdgeInfo {
  start : Int
  end : Int
  edge : @step.Ref
}

///|
fn find_edge(edges : Array[EdgeInfo], a : Int, b : Int) -> (@step.Ref, Bool) {
  // Returns (edge_ref, oriented_edge_orientation)
  // oriented_edge_orientation = true if the loop segment matches EDGE_CURVE direction.
  for i = 0; i < edges.length(); i = i + 1 {
    let e = edges[i]
    if e.start == a && e.end == b {
      return (e.edge, true)
    }
    if e.start == b && e.end == a {
      return (e.edge, false)
    }
  }
  // Should never happen for our fixed cube wiring.
  (edges[0].edge, true)
}

///|
fn face_loop(
  repo : @repository.Repository,
  edges : Array[EdgeInfo],
  verts : Array[Int],
) -> (@repository.Repository, @step.Ref) {
  let mut repo = repo
  let oe_refs : Array[@step.Ref] = []
  let n = verts.length()
  for i = 0; i < n; i = i + 1 {
    let a = verts[i]
    let b = verts[(i + 1) % n]
    let (edge_ref, ori) = find_edge(edges, a, b)
    let oe = @topology.OrientedEdge::new("", "*", "*", edge_ref, ori)
    let (r2, _id, oe_ref) = add(repo, @repository.any_entity_oriented_edge(oe))
    repo = r2
    oe_refs.push(oe_ref)
  }
  let edge_loop = @topology.EdgeLoop::new("", oe_refs)
  let (repo2, _id, loop_ref) = add(
    repo,
    @repository.any_entity_edge_loop(edge_loop),
  )
  (repo2, loop_ref)
}

///|
fn add_plane_face(
  repo : @repository.Repository,
  edges : Array[EdgeInfo],
  verts_cycle : Array[Int],
  location_pt : @step.Ref,
  axis_dir : @step.Ref,
  ref_dir : @step.Ref,
) -> (@repository.Repository, @step.Ref) {
  let mut repo = repo
  let a2p = @geometry.Axis2Placement3D::new("", location_pt, axis_dir, ref_dir)
  let (r2, _id, a2p_ref) = add(
    repo,
    @repository.any_entity_axis2_placement_3d(a2p),
  )
  repo = r2
  let plane = @geometry.Plane::new("", a2p_ref)
  let (r3, _id, plane_ref) = add(repo, @repository.any_entity_plane(plane))
  repo = r3
  let (r4, loop_ref) = face_loop(repo, edges, verts_cycle)
  repo = r4
  let fob = @topology.FaceOuterBound::new("", loop_ref, true)
  let (r5, _id, fob_ref) = add(
    repo,
    @repository.any_entity_face_outer_bound(fob),
  )
  repo = r5
  let face = @topology.AdvancedFace::new("", [fob_ref], plane_ref, true)
  let (r6, _id, face_ref) = add(
    repo,
    @repository.any_entity_advanced_face(face),
  )
  (r6, face_ref)
}

///|
pub fn Design::add_cube(
  self : Design,
  edge_mm : Double,
  name? : String = "cube",
  color? : Rgb = Rgb::{ r: 1.0, g: 0.6, b: 0.0 },
) -> Design {
  self.add_cube_at(edge_mm, name, color, 0.0, 0.0, 0.0)
}

///|
fn Design::add_cube_at(
  self : Design,
  edge_mm : Double,
  name : String,
  color : Rgb,
  tx : Double,
  ty : Double,
  tz : Double,
) -> Design {
  let mut repo = self.repo

  // Directions
  let (r1, _id, dx) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [1.0, 0.0, 0.0]),
    ),
  )
  repo = r1
  let (r2, _id, dy) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, 1.0, 0.0]),
    ),
  )
  repo = r2
  let (r3, _id, dz) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, 0.0, 1.0]),
    ),
  )
  repo = r3
  let (r4, _id, ndx) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [-1.0, 0.0, 0.0]),
    ),
  )
  repo = r4
  let (r5, _id, ndy) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, -1.0, 0.0]),
    ),
  )
  repo = r5
  let (r6, _id, ndz) = add(
    repo,
    @repository.any_entity_direction(
      @geometry.Direction::new("", [0.0, 0.0, -1.0]),
    ),
  )
  repo = r6

  // Vectors (unit)
  let (r7, _id, vx) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", dx, 1.0)),
  )
  repo = r7
  let (r8, _id, vy) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", dy, 1.0)),
  )
  repo = r8
  let (r9, _id, vz) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", dz, 1.0)),
  )
  repo = r9
  let (r10, _id, vnx) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", ndx, 1.0)),
  )
  repo = r10
  let (r11, _id, vny) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", ndy, 1.0)),
  )
  repo = r11
  let (r12, _id, _vnz) = add(
    repo,
    @repository.any_entity_vector(@geometry.Vector::new("", ndz, 1.0)),
  )
  repo = r12

  // Corner points (mm)
  let e = edge_mm
  let pts : Array[(Double, Double, Double)] = [
    (tx + 0.0, ty + 0.0, tz + 0.0),
    (tx + e, ty + 0.0, tz + 0.0),
    (tx + e, ty + e, tz + 0.0),
    (tx + 0.0, ty + e, tz + 0.0),
    (tx + 0.0, ty + 0.0, tz + e),
    (tx + e, ty + 0.0, tz + e),
    (tx + e, ty + e, tz + e),
    (tx + 0.0, ty + e, tz + e),
  ]
  let cp_refs : Array[@step.Ref] = []
  for i = 0; i < pts.length(); i = i + 1 {
    let (x, y, z) = pts[i]
    let cp = @geometry.CartesianPoint::new("", [x, y, z])
    let (r, _id, cp_ref) = add(repo, @repository.any_entity_cartesian_point(cp))
    repo = r
    cp_refs.push(cp_ref)
  }

  // Vertex points
  let vp_refs : Array[@step.Ref] = []
  for i = 0; i < cp_refs.length(); i = i + 1 {
    let vp = @topology.VertexPoint::new("", cp_refs[i])
    let (r, _id, vp_ref) = add(repo, @repository.any_entity_vertex_point(vp))
    repo = r
    vp_refs.push(vp_ref)
  }

  // Edge definitions: we create EDGE_CURVE directionally.
  // Indices refer to the vertex list above.
  let edge_defs : Array[(Int, Int, @step.Ref)] = [
    (0, 1, vx),
    (1, 2, vy),
    (2, 3, vnx),
    (3, 0, vny),
    (4, 5, vx),
    (5, 6, vy),
    (6, 7, vnx),
    (7, 4, vny),
    (0, 4, vz),
    (1, 5, vz),
    (2, 6, vz),
    (3, 7, vz),
  ]
  let edges : Array[EdgeInfo] = []
  for i = 0; i < edge_defs.length(); i = i + 1 {
    let (a, b, vec) = edge_defs[i]
    let line = @geometry.Line::new("", cp_refs[a], vec)
    let (rL, _id, line_ref) = add(repo, @repository.any_entity_line(line))
    repo = rL
    let ec = @topology.EdgeCurve::new(
      "",
      vp_refs[a],
      vp_refs[b],
      line_ref,
      true,
    )
    let (rE, _id, ec_ref) = add(repo, @repository.any_entity_edge_curve(ec))
    repo = rE
    edges.push(EdgeInfo::{ start: a, end: b, edge: ec_ref })
  }

  // Faces
  let face_refs : Array[@step.Ref] = []

  // bottom (z=0), outward normal -Z
  let (rB, fB) = add_plane_face(repo, edges, [0, 3, 2, 1], cp_refs[0], ndz, dx)
  repo = rB
  face_refs.push(fB)

  // top (z=e), outward normal +Z
  let (rT, fT) = add_plane_face(repo, edges, [4, 5, 6, 7], cp_refs[4], dz, dx)
  repo = rT
  face_refs.push(fT)

  // front (y=0), outward normal -Y
  let (rF, fF) = add_plane_face(repo, edges, [0, 1, 5, 4], cp_refs[0], ndy, dx)
  repo = rF
  face_refs.push(fF)

  // back (y=e), outward normal +Y
  let (rBk, fBk) = add_plane_face(repo, edges, [3, 7, 6, 2], cp_refs[3], dy, dx)
  repo = rBk
  face_refs.push(fBk)

  // left (x=0), outward normal -X
  let (rLft, fLft) = add_plane_face(
    repo,
    edges,
    [0, 4, 7, 3],
    cp_refs[0],
    ndx,
    dy,
  )
  repo = rLft
  face_refs.push(fLft)

  // right (x=e), outward normal +X
  let (rRgt, fRgt) = add_plane_face(
    repo,
    edges,
    [1, 2, 6, 5],
    cp_refs[1],
    dx,
    dy,
  )
  repo = rRgt
  face_refs.push(fRgt)
  let shell = @topology.ClosedShell::new("", face_refs)
  let (rS, _id, shell_ref) = add(
    repo,
    @repository.any_entity_closed_shell(shell),
  )
  repo = rS
  let brep = @topology.ManifoldSolidBrep::new("", shell_ref)
  let (rM, _id, brep_ref) = add(
    repo,
    @repository.any_entity_manifold_solid_brep(brep),
  )
  repo = rM

  // Units + representation context (complex instance)
  let dim_exp = @units.DimensionalExponents::new(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let (rDE, dim_exp_id, _dim_exp_ref) = add(
    repo,
    @repository.any_entity_dimensional_exponents(dim_exp),
  )
  repo = rDE
  let cx_radian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".RADIAN.")),
  ])
  let (r193, _id193, ref193) = add(
    repo,
    @repository.any_entity_complex_instance(cx_radian),
  )
  repo = r193
  let pa_meas = @units.PlaneAngleMeasureWithUnit::new("0.0174532925", ref193)
  let (r192, _id192, ref192) = add(
    repo,
    @repository.any_entity_plane_angle_measure_with_unit(pa_meas),
  )
  repo = r192
  let cx_degree = @context.ComplexInstance::new([
    @context.ComplexPart::ConversionBasedUnit(
      @units.ConversionBasedUnit::new("DEGREE", ref192),
    ),
    @context.ComplexPart::NamedUnit(
      @units.NamedUnit::new("#\{dim_exp_id.value}"),
    ),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
  ])
  let (r190, id190, _ref190) = add(
    repo,
    @repository.any_entity_complex_instance(cx_degree),
  )
  repo = r190
  let cx_steradian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".STERADIAN.")),
    @context.ComplexPart::SolidAngleUnit(@units.SolidAngleUnit::new()),
  ])
  let (r189, id189, _ref189) = add(
    repo,
    @repository.any_entity_complex_instance(cx_steradian),
  )
  repo = r189
  let cx_mm = @context.ComplexInstance::new([
    @context.ComplexPart::LengthUnit(@units.LengthUnit::new()),
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new(".MILLI.", ".METRE.")),
  ])
  let (r194, id194, ref194) = add(
    repo,
    @repository.any_entity_complex_instance(cx_mm),
  )
  repo = r194
  let unc = @units.UncertaintyMeasureWithUnit::new(
    "2.E-005", ref194, "DISTANCE_ACCURACY_VALUE", "Maximum Tolerance applied to model",
  )
  let (r188, id188, _ref188) = add(
    repo,
    @repository.any_entity_uncertainty_measure_with_unit(unc),
  )
  repo = r188
  let cx_ctx = @context.ComplexInstance::new([
    @context.ComplexPart::GeomRepCtx(
      @context.GeometricRepresentationContext::new(3),
    ),
    @context.ComplexPart::GlobUncCtx(
      @context.GlobalUncertaintyAssignedContext::new([id188]),
    ),
    @context.ComplexPart::GlobUnitCtx(
      @context.GlobalUnitAssignedContext::new([id194, id190, id189]),
    ),
    @context.ComplexPart::RepCtx(
      @context.RepresentationContext::new(name, "TOP_LEVEL_ASSEMBLY_PART"),
    ),
  ])
  let (r187, _id187, ref187) = add(
    repo,
    @repository.any_entity_complex_instance(cx_ctx),
  )
  repo = r187

  // Global placement for the shape representation
  let a2p_global = @geometry.Axis2Placement3D::new("", cp_refs[0], dz, dx)
  let (rA2, _id, a2p_global_ref) = add(
    repo,
    @repository.any_entity_axis2_placement_3d(a2p_global),
  )
  repo = rA2
  let shape_rep = @product.ShapeRepresentation::new(
    "\{name}-None",
    [a2p_global_ref],
    ref187,
  )
  let (r22, _id22, ref22) = add(
    repo,
    @repository.any_entity_shape_representation(shape_rep),
  )
  repo = r22
  let brep_rep = @product.AdvancedBrepShapeRepresentation::new(
    "\{name}-None",
    [brep_ref],
    ref187,
  )
  let (r11, _id11, ref11) = add(
    repo,
    @repository.any_entity_advanced_brep_shape_representation(brep_rep),
  )
  repo = r11
  let rel = @product.ShapeRepresentationRelationship::new(
    "None",
    "relationship between \{name}-None and \{name}-None",
    ref22,
    ref11,
  )
  let (r10, _id10, _ref10) = add(
    repo,
    @repository.any_entity_shape_representation_relationship(rel),
  )
  repo = r10

  // Product structure
  let app_ctx = @product.ApplicationContext::new(
    "core data for automotive mechanical design processes",
  )
  let (r21, _id21, ref21) = add(
    repo,
    @repository.any_entity_application_context(app_ctx),
  )
  repo = r21
  let app_proto = @product.ApplicationProtocolDefinition::new(
    "international standard", "automotive_design", 2010, ref21,
  )
  let (r20, _id20, _ref20) = add(
    repo,
    @repository.any_entity_application_protocol_definition(app_proto),
  )
  repo = r20
  let prod_ctx = @product.ProductContext::new(" ", ref21, "mechanical")
  let (r19, _id19, ref19) = add(
    repo,
    @repository.any_entity_product_context(prod_ctx),
  )
  repo = r19
  let product = @product.Product::new(name, name, " ", [ref19])
  let (r18, _id18, ref18) = add(repo, @repository.any_entity_product(product))
  repo = r18
  let cat = @product.ProductRelatedProductCategory::new("part", "", [ref18])
  let (r17, _id17, _ref17) = add(
    repo,
    @repository.any_entity_product_related_product_category(cat),
  )
  repo = r17
  let form = @product.ProductDefinitionFormationWithSpecifiedSource::new(
    " ", " ", ref18, ".NOT_KNOWN.",
  )
  let (r16, _id16, ref16) = add(
    repo,
    @repository.any_entity_product_definition_formation_with_specified_source(
      form,
    ),
  )
  repo = r16
  let def_ctx = @product.ProductDefinitionContext::new(
    "part definition", ref21, "design",
  )
  let (r15, _id15, ref15) = add(
    repo,
    @repository.any_entity_product_definition_context(def_ctx),
  )
  repo = r15
  let prod_def = @product.ProductDefinition::new(" ", "", ref16, ref15)
  let (r14, _id14, ref14) = add(
    repo,
    @repository.any_entity_product_definition(prod_def),
  )
  repo = r14
  let pds = @product.ProductDefinitionShape::new("", "", ref14)
  let (r13, _id13, ref13) = add(
    repo,
    @repository.any_entity_product_definition_shape(pds),
  )
  repo = r13
  let sdr = @product.ShapeDefinitionRepresentation::new(ref13, ref22)
  let (r12, _id12, _ref12) = add(
    repo,
    @repository.any_entity_shape_definition_representation(sdr),
  )
  repo = r12

  // Presentation styling
  let rgb = @presentation.ColorRgb::new("Orange", color.r, color.g, color.b)
  let (r31, _id31, ref31) = add(repo, @repository.any_entity_color_rgb(rgb))
  repo = r31
  let fas_col = @presentation.FillAreaStyleColor::new("", ref31)
  let (r30, _id30, ref30) = add(
    repo,
    @repository.any_entity_fill_area_style_color(fas_col),
  )
  repo = r30
  let fas = @presentation.FillAreaStyle::new("", [ref30])
  let (r29, _id29, ref29) = add(
    repo,
    @repository.any_entity_fill_area_style(fas),
  )
  repo = r29
  let ssfa = @presentation.SurfaceStyleFillArea::new(ref29)
  let (r28, _id28, ref28) = add(
    repo,
    @repository.any_entity_surface_style_fill_area(ssfa),
  )
  repo = r28
  let sss = @presentation.SurfaceSideStyle::new("", [ref28])
  let (r27, _id27, ref27) = add(
    repo,
    @repository.any_entity_surface_side_style(sss),
  )
  repo = r27
  let ssu = @presentation.SurfaceStyleUsage::new(".BOTH.", ref27)
  let (r26, _id26, ref26) = add(
    repo,
    @repository.any_entity_surface_style_usage(ssu),
  )
  repo = r26
  let psa = @presentation.PresentationStyleAssignment::new([ref26])
  let (r25, _id25, ref25) = add(
    repo,
    @repository.any_entity_presentation_style_assignment(psa),
  )
  repo = r25
  let styled = @presentation.StyledItem::new("", [ref25], brep_ref)
  let (r24, _id24, ref24) = add(
    repo,
    @repository.any_entity_styled_item(styled),
  )
  repo = r24
  let layer = @presentation.PresentationLayerAssignment::new("1", "Layer 1", [
    brep_ref,
  ])
  let (r23, _id23, _ref23) = add(
    repo,
    @repository.any_entity_presentation_layer_assignment(layer),
  )
  repo = r23
  let md = @presentation.MechanicalDesignGeometricPresentationRepresentation::new(
    "",
    [ref24],
    ref187,
  )
  let (r186, _id186, _ref186) = add(
    repo,
    @repository.any_entity_mechanical_design_geometric_presentation_representation(
      md,
    ),
  )
  repo = r186
  Design::{ repo, next_solid_id: self.next_solid_id }
}
