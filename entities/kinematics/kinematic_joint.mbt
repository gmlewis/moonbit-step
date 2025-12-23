///|
// Represents a KINEMATIC_JOINT entity.
// Example:
//   KINEMATIC_JOINT('name', #10, #20)
// where #10 and #20 are KINEMATIC_LINKs.
pub struct KinematicJoint {
  name : String
  first_link : @step.Ref
  second_link : @step.Ref
}

///|
pub fn KinematicJoint::new(
  name : String,
  first_link : @step.Ref,
  second_link : @step.Ref,
) -> KinematicJoint {
  KinematicJoint::{ name, first_link, second_link }
}

///|
pub impl @step.Entity for KinematicJoint with to_step(self) {
  let l1 = "#\{self.first_link.id.value}"
  let l2 = "#\{self.second_link.id.value}"
  "KINEMATIC_JOINT(\{@step.step_str(self.name)},\{l1},\{l2})"
}
