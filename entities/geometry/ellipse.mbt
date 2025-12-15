///|
// Represents an ELLIPSE entity.
// Example from MachineContactMedium.step:
//   ELLIPSE('',#613,0.1233...,0.1177...)
pub struct Ellipse {
  name : String
  position : @step.Ref
  semi_axis_1_literal : String
  semi_axis_2_literal : String
}

///|
pub fn Ellipse::new(
  name : String,
  position : @step.Ref,
  semi_axis_1_literal : String,
  semi_axis_2_literal : String,
) -> Ellipse {
  Ellipse::{ name, position, semi_axis_1_literal, semi_axis_2_literal }
}

///|
pub impl @step.Entity for Ellipse with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "ELLIPSE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.semi_axis_1_literal},\{self.semi_axis_2_literal})"
}
