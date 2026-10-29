///|
/// Transform is a rigid affine transform (rotation followed by translation)
/// used to compose a parent `SceneNode`'s placement with a child's own.
///
/// Solid compilers apply a node's own rotate-then-translate to every point.
/// Composite nodes (`Union`, `Difference`) have no geometry of their own, so
/// their placement must instead be applied to each compiled child. Threading a
/// `Transform` down through the compilers keeps that composition in one place
/// and preserves the existing single-node convention.
pub(all) struct Transform {
  rot : Matrix3x3
  trans : Vec3
}

///|
/// Transform::identity returns the no-op transform.
pub fn Transform::identity() -> Transform {
  Transform::{ rot: rotation_matrix(0.0, 0.0, 0.0), trans: (0.0, 0.0, 0.0), }
}

///|
/// Transform::from_node captures a node's rotation (degrees) and translation.
pub fn Transform::from_node(node : SceneNode) -> Transform {
  Transform::{
    rot: rotation_matrix(node.rx, node.ry, node.rz),
    trans: (node.tx, node.ty, node.tz),
  }
}

///|
/// Transform::compose returns `outer` applied after `inner`:
/// `compose(outer, inner).apply(p) == outer.apply(inner.apply(p))`.
pub fn Transform::compose(outer : Transform, inner : Transform) -> Transform {
  let t = apply_matrix(outer.rot, inner.trans)
  Transform::{
    rot: multiply_matrices(outer.rot, inner.rot),
    trans: (t.0 + outer.trans.0, t.1 + outer.trans.1, t.2 + outer.trans.2),
  }
}

///|
/// Transform::apply maps a point through the rotation and translation.
pub fn Transform::apply(self : Transform, p : Vec3) -> Vec3 {
  let r = apply_matrix(self.rot, p)
  (r.0 + self.trans.0, r.1 + self.trans.1, r.2 + self.trans.2)
}

///|
/// Transform::apply_dir maps a direction through the rotation only.
pub fn Transform::apply_dir(self : Transform, v : Vec3) -> Vec3 {
  apply_matrix(self.rot, v)
}

///|
/// node_transform combines an optional parent transform with a node's own.
fn node_transform(node : SceneNode, parent : Transform?) -> Transform {
  let own = Transform::from_node(node)
  match parent {
    None => own
    Some(p) => Transform::compose(p, own)
  }
}
