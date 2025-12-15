///|
// Represents a TOROIDAL_SURFACE entity.
// Example from kicadoutput01-roundtrip.step:
//   TOROIDAL_SURFACE('',#98,0.4,0.4)
pub struct ToroidalSurface {
  name : String
  position : @step.Ref
  major_radius_literal : String
  minor_radius_literal : String
}

///|
pub fn ToroidalSurface::new(
  name : String,
  position : @step.Ref,
  major_radius_literal : String,
  minor_radius_literal : String,
) -> ToroidalSurface {
  ToroidalSurface::{
    name,
    position,
    major_radius_literal,
    minor_radius_literal,
  }
}

///|
pub impl @step.Entity for ToroidalSurface with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "TOROIDAL_SURFACE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.major_radius_literal},\{self.minor_radius_literal})"
}
