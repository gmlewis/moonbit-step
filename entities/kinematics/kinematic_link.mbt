///|
// Represents a KINEMATIC_LINK entity.
// Example:
//   KINEMATIC_LINK('link name')
pub struct KinematicLink {
  name : String
}

///|
pub fn KinematicLink::new(name : String) -> KinematicLink {
  KinematicLink::{ name, }
}

///|
pub impl @step.Entity for KinematicLink with to_step(self) {
  "KINEMATIC_LINK(\{@step.step_str(self.name)})"
}
