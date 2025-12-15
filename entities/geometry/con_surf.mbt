///|
// Represents a CONICAL_SURFACE entity.
// Example from MachineContactMedium.step:
//   CONICAL_SURFACE('',#611,0.3500599520011,0.140686945962564)
pub struct ConicalSurface {
  name : String
  position : @step.Ref
  radius_literal : String
  semi_angle_literal : String
}

///|
pub fn ConicalSurface::new(
  name : String,
  position : @step.Ref,
  radius_literal : String,
  semi_angle_literal : String,
) -> ConicalSurface {
  ConicalSurface::{ name, position, radius_literal, semi_angle_literal }
}

///|
pub impl @step.Entity for ConicalSurface with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "CONICAL_SURFACE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.radius_literal},\{self.semi_angle_literal})"
}
