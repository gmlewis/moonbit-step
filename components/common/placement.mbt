///|
/// Placement is a rigid transform (rotation about the origin, then
/// translation) used to position a component layer or an assembly instance.
///
/// The rotation convention matches the existing `@cad` DSL: angles are in
/// degrees and the matrix is `Rz * Ry * Rx`, so a placement built here lands
/// the same way as `SceneNode::rotate_x/rotate_y/rotate_z`.
///
/// `Placement::compose(outer, inner)` applies `inner` first, then `outer`:
///
/// ```text
/// compose(outer, inner).apply_point(p) == outer.apply_point(inner.apply_point(p))
/// ```
#derive(Debug, Eq)
pub(all) struct Placement {
  rot : @cad.Matrix3x3
  trans : @cad.Vec3
}

///|
pub extend Placement with @debug.Debug::{to_repr}

///|
pub extend Placement with Eq::{not_equal, equal}

///|
/// Placement::identity is the no-op placement.
pub fn Placement::identity() -> Placement {
  {
    rot: @cad.Matrix3x3::{
      m00: 1.0,
      m01: 0.0,
      m02: 0.0,
      m10: 0.0,
      m11: 1.0,
      m12: 0.0,
      m20: 0.0,
      m21: 0.0,
      m22: 1.0,
    },
    trans: (0.0, 0.0, 0.0),
  }
}

///|
/// Placement::translation moves by `(x, y, z)` millimetres.
pub fn Placement::translation(x : Double, y : Double, z : Double) -> Placement {
  { rot: Placement::identity().rot, trans: (x, y, z), }
}

///|
/// Placement::rotation_deg rotates about X, then Y, then Z, in degrees.
pub fn Placement::rotation_deg(
  rx : Double,
  ry : Double,
  rz : Double,
) -> Placement {
  { rot: rotation_matrix_deg(rx, ry, rz), trans: (0.0, 0.0, 0.0), }
}

///|
/// Placement::rotation_x rotates about +X by `angle_deg`.
pub fn Placement::rotation_x(angle_deg : Double) -> Placement {
  Placement::rotation_deg(angle_deg, 0.0, 0.0)
}

///|
/// Placement::rotation_y rotates about +Y by `angle_deg`.
pub fn Placement::rotation_y(angle_deg : Double) -> Placement {
  Placement::rotation_deg(0.0, angle_deg, 0.0)
}

///|
/// Placement::rotation_z rotates about +Z by `angle_deg`.
pub fn Placement::rotation_z(angle_deg : Double) -> Placement {
  Placement::rotation_deg(0.0, 0.0, angle_deg)
}

///|
/// Placement::rotation_axis_angle rotates about `axis` by `angle_rad` using
/// Rodrigues' formula. A zero-length axis yields the identity rotation.
///
/// This is the rotation used by the mate-snapping helper: `MatePair` twist is
/// expressed about the parent connector axis, which is not generally one of the
/// Euler axes. The matrix convention remains the `Rz * Ry * Rx` layout of
/// `Placement`, so the result composes exactly like every other placement.
pub fn Placement::rotation_axis_angle(
  axis : @cad.Vec3,
  angle_rad : Double,
) -> Placement {
  let (ax, ay, az) = axis
  let len = (ax * ax + ay * ay + az * az).sqrt()
  if len < 1.0e-15 {
    return Placement::identity()
  }
  let ux = ax / len
  let uy = ay / len
  let uz = az / len
  let c = @math.cos(angle_rad)
  let s = @math.sin(angle_rad)
  let t = 1.0 - c
  {
    rot: @cad.Matrix3x3::{
      m00: t * ux * ux + c,
      m01: t * ux * uy - s * uz,
      m02: t * ux * uz + s * uy,
      m10: t * ux * uy + s * uz,
      m11: t * uy * uy + c,
      m12: t * uy * uz - s * ux,
      m20: t * ux * uz - s * uy,
      m21: t * uy * uz + s * ux,
      m22: t * uz * uz + c,
    },
    trans: (0.0, 0.0, 0.0),
  }
}

///|
/// Placement::at builds a placement with a rotation followed by a translation.
pub fn Placement::at(
  x : Double,
  y : Double,
  z : Double,
  rx~ : Double = 0.0,
  ry~ : Double = 0.0,
  rz~ : Double = 0.0,
) -> Placement {
  Placement::compose(
    Placement::translation(x, y, z),
    Placement::rotation_deg(rx, ry, rz),
  )
}

///|
/// Placement::compose returns `outer` applied after `inner`.
pub fn Placement::compose(outer : Placement, inner : Placement) -> Placement {
  let t = apply_matrix(outer.rot, inner.trans)
  {
    rot: multiply_matrices(outer.rot, inner.rot),
    trans: (t.0 + outer.trans.0, t.1 + outer.trans.1, t.2 + outer.trans.2),
  }
}

///|
/// Placement::apply_point maps a point through the rotation and translation.
pub fn Placement::apply_point(self : Placement, p : @cad.Vec3) -> @cad.Vec3 {
  let r = apply_matrix(self.rot, p)
  (r.0 + self.trans.0, r.1 + self.trans.1, r.2 + self.trans.2)
}

///|
/// Placement::apply_dir maps a direction through the rotation only.
pub fn Placement::apply_dir(self : Placement, v : @cad.Vec3) -> @cad.Vec3 {
  apply_matrix(self.rot, v)
}

///|
/// Placement::inverse returns the reverse rigid transform.
pub fn Placement::inverse(self : Placement) -> Placement {
  let rt = transpose(self.rot)
  let t = apply_matrix(rt, self.trans)
  { rot: rt, trans: (-t.0, -t.1, -t.2), }
}

///|
/// Placement::to_euler returns the rotation as `(rx, ry, rz)` degrees in the
/// same convention as `@cad` scene nodes.
pub fn Placement::to_euler(self : Placement) -> @cad.Vec3 {
  @cad.matrix_to_euler(self.rot)
}

///|
/// rotation_matrix_deg builds the `Rz * Ry * Rx` rotation matrix used by the
/// CAD scene graph.
pub fn rotation_matrix_deg(
  rx : Double,
  ry : Double,
  rz : Double,
) -> @cad.Matrix3x3 {
  let rad_x = rx * @math.PI / 180.0
  let rad_y = ry * @math.PI / 180.0
  let rad_z = rz * @math.PI / 180.0
  let sx = @math.sin(rad_x)
  let cx = @math.cos(rad_x)
  let sy = @math.sin(rad_y)
  let cy = @math.cos(rad_y)
  let sz = @math.sin(rad_z)
  let cz = @math.cos(rad_z)
  @cad.Matrix3x3::{
    m00: cy * cz,
    m01: sx * sy * cz - cx * sz,
    m02: cx * sy * cz + sx * sz,
    m10: cy * sz,
    m11: sx * sy * sz + cx * cz,
    m12: cx * sy * sz - sx * cz,
    m20: -sy,
    m21: sx * cy,
    m22: cx * cy,
  }
}

///|
fn apply_matrix(m : @cad.Matrix3x3, p : @cad.Vec3) -> @cad.Vec3 {
  let (x, y, z) = p
  (
    m.m00 * x + m.m01 * y + m.m02 * z,
    m.m10 * x + m.m11 * y + m.m12 * z,
    m.m20 * x + m.m21 * y + m.m22 * z,
  )
}

///|
fn multiply_matrices(a : @cad.Matrix3x3, b : @cad.Matrix3x3) -> @cad.Matrix3x3 {
  @cad.Matrix3x3::{
    m00: a.m00 * b.m00 + a.m01 * b.m10 + a.m02 * b.m20,
    m01: a.m00 * b.m01 + a.m01 * b.m11 + a.m02 * b.m21,
    m02: a.m00 * b.m02 + a.m01 * b.m12 + a.m02 * b.m22,
    m10: a.m10 * b.m00 + a.m11 * b.m10 + a.m12 * b.m20,
    m11: a.m10 * b.m01 + a.m11 * b.m11 + a.m12 * b.m21,
    m12: a.m10 * b.m02 + a.m11 * b.m12 + a.m12 * b.m22,
    m20: a.m20 * b.m00 + a.m21 * b.m10 + a.m22 * b.m20,
    m21: a.m20 * b.m01 + a.m21 * b.m11 + a.m22 * b.m21,
    m22: a.m20 * b.m02 + a.m21 * b.m12 + a.m22 * b.m22,
  }
}

///|
fn transpose(m : @cad.Matrix3x3) -> @cad.Matrix3x3 {
  @cad.Matrix3x3::{
    m00: m.m00,
    m01: m.m10,
    m02: m.m20,
    m10: m.m01,
    m11: m.m11,
    m12: m.m21,
    m20: m.m02,
    m21: m.m12,
    m22: m.m22,
  }
}
