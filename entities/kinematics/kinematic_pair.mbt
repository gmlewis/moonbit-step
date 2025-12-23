///|
// Represents a KINEMATIC_PAIR entity.
// Example:
//   KINEMATIC_PAIR('name', 'description', #10)
// where #10 is a KINEMATIC_JOINT.
pub struct KinematicPair {
  name : String
  description : String
  joint : @step.Ref
}

///|
pub fn KinematicPair::new(
  name : String,
  description : String,
  joint : @step.Ref,
) -> KinematicPair {
  KinematicPair::{ name, description, joint }
}

///|
pub impl @step.Entity for KinematicPair with to_step(self) {
  let joint_str = "#\{self.joint.id.value}"
  "KINEMATIC_PAIR(\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{joint_str})"
}
