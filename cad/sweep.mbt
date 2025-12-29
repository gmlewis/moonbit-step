///|
/// SweptProfile::new generates a new Shape by sweeping a 2D profile along a 3D path.
/// Note that the resulting Shape has no end caps; both ends are open.
pub fn SweptProfile::new(path~ : SweepPath, profile~ : SweepProfile) -> Shape {
  Shape::SweptProfile({ path, profile })
}

///|
fn compile_swept_profile(
  _ctx : StepContext,
  _node : SceneNode,
  _s : SweptProfile,
) -> @step.Ref {
  // TODO
  { id: { value: 0 } }
}
