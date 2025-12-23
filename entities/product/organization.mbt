///|
// Represents an ORGANIZATION entity.
// Example:
//   ORGANIZATION('id', 'name', 'description')
pub struct Organization {
  id : String
  name : String
  description : String
}

///|
pub fn Organization::new(
  id : String,
  name : String,
  description : String,
) -> Organization {
  Organization::{ id, name, description }
}

///|
pub impl @step.Entity for Organization with to_step(self) {
  "ORGANIZATION(\{@step.step_str(self.id)},\{@step.step_str(self.name)},\{@step.step_str(self.description)})"
}
