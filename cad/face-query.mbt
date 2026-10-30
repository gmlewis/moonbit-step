///|
// Planar face discovery and sketch-on-face placement.
//
// After `Design::compile()` the repository holds a full B-Rep. This module
// walks `MANIFOLD_SOLID_BREP -> CLOSED_SHELL -> ADVANCED_FACE -> PLANE` and
// returns a `FaceInfo` for each planar face, including a right-handed frame
// (origin, u, v, normal) so a 2D profile can be mapped onto the face.
//
// This mirrors MakerCad's `Faces().AlignedWith(plane).SortByZ(...)` query
// vocabulary while keeping the kernel-free writer deterministic: a profile
// placed on a face is still *nominal* in the flat STEP backend. Use the
// OCCT-evaluated export (`write_step_evaluated`) or the Blender backend for a
// real trimmed cut.

///|
/// FaceInfo describes one planar B-Rep face in world coordinates.
///
/// `u`/`v`/`normal` are orthonormal with `u x v = normal`. `point` is the
/// plane placement's origin (a point on the face), and `boundary` holds the
/// outer loop's vertices in traversal order.
pub struct FaceInfo {
  normal : Vec3
  point : Vec3
  area : Double
  u : Vec3
  v : Vec3
  boundary : Array[Vec3]
  face_id : Int32
  surface_id : Int32
}

///|
/// FaceInfo::center returns the average of the outer loop vertices, a point
/// near the middle of the face's boundary.
pub fn FaceInfo::center(self : FaceInfo) -> Vec3 {
  let n = self.boundary.length()
  // A circular face's loop has fewer than three sampled vertices; its plane
  // origin is the true center.
  if n < 3 {
    return self.point
  }
  let mut x = 0.0
  let mut y = 0.0
  let mut z = 0.0
  for (px, py, pz) in self.boundary {
    x = x + px
    y = y + py
    z = z + pz
  }
  let d = n.to_double()
  (x / d, y / d, z / d)
}

///|
/// FaceInfo::local_xy maps a world point into the face frame's 2D coordinates.
pub fn FaceInfo::local_xy(self : FaceInfo, p : Vec3) -> Vec2 {
  let d = v_sub(p, self.point)
  (v_dot(d, self.u), v_dot(d, self.v))
}

///|
fn neg3(v : Vec3) -> Vec3 {
  let (x, y, z) = v
  (-x, -y, -z)
}

///|
fn face_cart_point(repo : @repository.Repository, r : @step.Ref) -> Vec3? {
  match repo.get(r.id) {
    Some(CartesianPoint(p)) =>
      if p.coordinates.length() >= 3 {
        Some((p.coordinates[0], p.coordinates[1], p.coordinates[2]))
      } else {
        None
      }
    _ => None
  }
}

///|
fn face_direction(repo : @repository.Repository, r : @step.Ref) -> Vec3? {
  match repo.get(r.id) {
    Some(Direction(d)) =>
      if d.ratios.length() >= 3 {
        Some((d.ratios[0], d.ratios[1], d.ratios[2]))
      } else {
        None
      }
    _ => None
  }
}

///|
fn face_loop_area(pts : Array[Vec3]) -> Double {
  let n = pts.length()
  if n < 3 {
    return 0.0
  }
  let mut ax = 0.0
  let mut ay = 0.0
  let mut az = 0.0
  for i in 0..<n {
    let (x1, y1, z1) = pts[i]
    let (x2, y2, z2) = pts[(i + 1) % n]
    ax = ax + (y1 * z2 - z1 * y2)
    ay = ay + (z1 * x2 - x1 * z2)
    az = az + (x1 * y2 - y1 * x2)
  }
  (ax * ax + ay * ay + az * az).sqrt() / 2.0
}

///|
/// face_loop_boundary returns the outer loop vertices and, when the loop is a single
/// circular edge (a cylinder cap), that circle's radius.
fn face_loop_boundary(
  repo : @repository.Repository,
  face : @topology.AdvancedFace,
) -> (Array[Vec3], Double?) {
  let pts : Array[Vec3] = []
  let mut circle_radius : Double? = None
  let mut edge_count = 0
  if face.bounds.length() == 0 {
    return (pts, None)
  }
  let loop_ref = match repo.get(face.bounds[0].id) {
    Some(FaceOuterBound(b)) => Some(b.bound)
    Some(FaceBound(b)) => Some(b.bound)
    _ => None
  }
  match loop_ref {
    None => ()
    Some(lr) =>
      match repo.get(lr.id) {
        Some(EdgeLoop(lp)) =>
          for oe_ref in lp.edges {
            match repo.get(oe_ref.id) {
              Some(OrientedEdge(oe)) =>
                match repo.get(oe.edge_element.id) {
                  Some(EdgeCurve(ec)) => {
                    edge_count = edge_count + 1
                    match repo.get(ec.edge_geometry.id) {
                      Some(Circle(c)) =>
                        circle_radius = Some(parse_num(c.radius_literal))
                      _ => ()
                    }
                    let vref = if oe.orientation {
                      ec.edge_start
                    } else {
                      ec.edge_end
                    }
                    match repo.get(vref.id) {
                      Some(VertexPoint(vp)) =>
                        match face_cart_point(repo, vp.vertex_geometry) {
                          Some(p) => pts.push(p)
                          None => ()
                        }
                      _ => ()
                    }
                  }
                  _ => ()
                }
              _ => ()
            }
          }
        _ => ()
      }
  }
  // Only a loop made of exactly one circular edge is a true disk.
  let radius = if edge_count == 1 { circle_radius } else { None }
  (pts, radius)
}

///|
/// planar_face_info reads one `ADVANCED_FACE`. Returns `None` for non-planar surfaces
/// (cylindrical, conical, B-spline) and for malformed references.
fn planar_face_info(
  repo : @repository.Repository,
  face_ref : @step.Ref,
) -> FaceInfo? {
  let af = match repo.get(face_ref.id) {
    Some(AdvancedFace(af)) => af
    _ => return None
  }
  let plane = match repo.get(af.surface.id) {
    Some(Plane(p)) => p
    _ => return None
  }
  let a2p = match repo.get(plane.position.id) {
    Some(Axis2Placement3D(a)) => a
    _ => return None
  }
  let origin = match face_cart_point(repo, a2p.location) {
    Some(p) => p
    None => return None
  }
  let axis = match face_direction(repo, a2p.axis) {
    Some(d) => v_norm(d)
    None => return None
  }
  let ref_direction = match face_direction(repo, a2p.ref_direction) {
    Some(d) => d
    None => return None
  }
  // `same_sense` says whether the face normal agrees with the plane normal.
  let normal = if af.same_sense { axis } else { neg3(axis) }
  let u = v_norm(ref_direction)
  let v = v_norm(v_cross(normal, u))
  let (boundary, radius) = face_loop_boundary(repo, af)
  let mut area = face_loop_area(boundary)
  if area < 1.0e-9 {
    match radius {
      Some(r) => area = @math.PI * r * r
      None => ()
    }
  }
  Some({
    normal,
    point: origin,
    area,
    u,
    v,
    boundary,
    face_id: face_ref.id.value,
    surface_id: af.surface.id.value,
  })
}

///|
/// planar_faces_of returns every planar face of every `MANIFOLD_SOLID_BREP` in
/// a compiled repository.
pub fn planar_faces_of(repo : @repository.Repository) -> Array[FaceInfo] {
  let out : Array[FaceInfo] = []
  repo.each(fn(entity) {
    match entity {
      ManifoldSolidBrep(brep) =>
        match repo.get(brep.outer.id) {
          Some(ClosedShell(shell)) =>
            for face_ref in shell.faces {
              match planar_face_info(repo, face_ref) {
                Some(fi) => out.push(fi)
                None => ()
              }
            }
          _ => ()
        }
      _ => ()
    }
  })
  out
}

///|
/// FaceSet is a small queryable collection returned by
/// `Design::planar_faces`.
pub struct FaceSet {
  faces : Array[FaceInfo]
}

///|
pub fn FaceSet::length(self : FaceSet) -> Int32 {
  self.faces.length()
}

///|
pub fn FaceSet::is_empty(self : FaceSet) -> Bool {
  self.faces.is_empty()
}

///|
pub fn FaceSet::to_array(self : FaceSet) -> Array[FaceInfo] {
  self.faces
}

///|
/// FaceSet::aligned_with keeps faces whose normal points along `dir`.
///
/// `dir` need not be normalised. `tol` is a cosine tolerance: a face is kept
/// when `dot(normal, dir) >= 1 - tol` (default 1e-6, i.e. exact alignment).
pub fn FaceSet::aligned_with(
  self : FaceSet,
  dir : Vec3,
  tol~ : Double = 1.0e-6,
) -> FaceSet {
  let d = v_norm(dir)
  { faces: self.faces.filter(fn(f) { v_dot(f.normal, d) >= 1.0 - tol }), }
}

///|
/// FaceSet::sort_by_z orders faces by the z coordinate of their plane origin.
pub fn FaceSet::sort_by_z(self : FaceSet, ascending~ : Bool = true) -> FaceSet {
  let faces = self.faces.copy()
  if ascending {
    faces.sort_by(fn(a, b) { a.point.2.compare(b.point.2) })
  } else {
    faces.sort_by(fn(a, b) { b.point.2.compare(a.point.2) })
  }
  { faces, }
}

///|
/// FaceSet::first_matching returns the first face satisfying `pred`.
pub fn FaceSet::first_matching(
  self : FaceSet,
  pred : (FaceInfo) -> Bool,
) -> FaceInfo? {
  for f in self.faces {
    if pred(f) {
      return Some(f)
    }
  }
  None
}

///|
/// Design::planar_faces compiles the design and queries its planar faces.
///
/// The returned faces are in world coordinates (node placements already
/// applied). Boolean nodes are compiled nominally, so query the faces of a
/// plain solid rather than of a `difference`.
pub fn Design::planar_faces(self : Design) -> FaceSet {
  { faces: planar_faces_of(self.compile()), }
}

///|
/// face_frame_matrix returns the rotation whose columns are the face's
/// u, v, and normal axes.
fn face_frame_matrix(face : FaceInfo) -> Matrix3x3 {
  let (ux, uy, uz) = face.u
  let (vx, vy, vz) = face.v
  let (nx, ny, nz) = face.normal
  {
    m00: ux,
    m01: vx,
    m02: nx,
    m10: uy,
    m11: vy,
    m12: ny,
    m20: uz,
    m21: vz,
    m22: nz,
  }
}

///|
/// Profile2D::on_face places the profile on `face` and extrudes it `height_mm`
/// along the face normal.
///
/// With `into=false` the extrusion starts at `face.point` and grows outward.
/// With `into=true` it ends at the face and grows inward, which makes a cutter
/// for `difference`. `offset` shifts the placement along the normal, and
/// `center` translates the profile within the face's `u`/`v` frame.
pub fn Profile2D::on_face(
  self : Profile2D,
  face : FaceInfo,
  height_mm : Double,
  into~ : Bool = false,
  offset~ : Double = 0.0,
  center~ : Vec2 = (0.0, 0.0),
  name~ : String = "on-face",
  color~ : Rgb = Rgb::orange(),
) -> SceneNode {
  let (rx, ry, rz) = matrix_to_euler(face_frame_matrix(face))
  let (nx, ny, nz) = face.normal
  let shift = if into { offset - height_mm } else { offset }
  let (ox, oy, oz) = face.point
  let (cx, cy) = center
  let profile = if cx == 0.0 && cy == 0.0 {
    self
  } else {
    {
      outer: translate_pts(self.outer, cx, cy),
      holes: self.holes.map(fn(h) { translate_pts(h, cx, cy) }),
    }
  }
  {
    shape: Shape::ExtrudedProfile({ profile, height_mm, }),
    name,
    color,
    tx: ox + nx * shift,
    ty: oy + ny * shift,
    tz: oz + nz * shift,
    rx,
    ry,
    rz,
  }
}

///|
/// ExtrudedProfile::on_face places an existing extruded profile on a face.
pub fn ExtrudedProfile::on_face(
  self : ExtrudedProfile,
  face : FaceInfo,
  into~ : Bool = false,
  offset~ : Double = 0.0,
  center~ : Vec2 = (0.0, 0.0),
  name~ : String = "on-face",
  color~ : Rgb = Rgb::orange(),
) -> SceneNode {
  self.profile.on_face(
    face,
    self.height_mm,
    into~,
    offset~,
    center~,
    name~,
    color~,
  )
}

///|
/// Design::add_profile_on_face adds a profile extruded on `face` as a node.
///
/// In the flat STEP backend this is a new solid placed relative to the face;
/// combine it with `difference()` for a nominal cut, or export with
/// `write_step_evaluated` for real trimming.
pub fn Design::add_profile_on_face(
  self : Design,
  profile : Profile2D,
  face : FaceInfo,
  height_mm : Double,
  into~ : Bool = false,
  offset~ : Double = 0.0,
  center~ : Vec2 = (0.0, 0.0),
  name~ : String = "on-face",
  color~ : Rgb = Rgb::orange(),
) -> Design {
  self.add(
    profile.on_face(face, height_mm, into~, offset~, center~, name~, color~),
  )
}

///|
/// cut_on_face builds a `difference` that cuts `profile` `depth` into `base`
/// from `face`.
///
/// The cutter is extended by `overshoot` past the face so the evaluated
/// boolean does not leave a skin. STEP export remains nominal unless the
/// design is evaluated with OCCT (`write_step_evaluated`) or Blender.
pub fn cut_on_face(
  base : SceneNode,
  profile : Profile2D,
  face : FaceInfo,
  depth : Double,
  name~ : String = "cut-on-face",
  overshoot~ : Double = 0.5,
  center~ : Vec2 = (0.0, 0.0),
  color~ : Rgb = Rgb::grey(),
) -> SceneNode {
  let cutter = profile.on_face(
    face,
    depth + overshoot,
    into=true,
    offset=overshoot,
    center~,
    name=name + "-cutter",
    color~,
  )
  difference(base, [cutter], name~)
}
