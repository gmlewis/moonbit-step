///|
// Represents a SPHERICAL_SURFACE entity.
//
// Example:
//   SPHERICAL_SURFACE('',#98,2.75)
pub struct SphericalSurface {
  name : String
  position : @step.Ref
  radius_literal : String
}

///|
pub fn SphericalSurface::new(
  name : String,
  position : @step.Ref,
  radius_literal : String,
) -> SphericalSurface {
  SphericalSurface::{ name, position, radius_literal, }
}

///|
pub impl @step.Entity for SphericalSurface with fn to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "SPHERICAL_SURFACE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.radius_literal})"
}
