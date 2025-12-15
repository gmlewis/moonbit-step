///|
// Represents a CIRCLE entity.
// Example from MachineContactMedium.step:
//   CIRCLE('',#600,0.435)
pub struct Circle {
  name : String
  position : @step.Ref
  radius_literal : String
}

///|
pub fn Circle::new(
  name : String,
  position : @step.Ref,
  radius_literal : String,
) -> Circle {
  Circle::{ name, position, radius_literal }
}

///|
pub impl @step.Entity for Circle with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "CIRCLE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.radius_literal})"
}
