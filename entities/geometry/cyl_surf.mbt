///|
// Represents a CYLINDRICAL_SURFACE entity.
// Example from MachineContactMedium.step:
//   CYLINDRICAL_SURFACE('',#602,0.435)
pub struct CylindricalSurface {
  name : String
  position : @step.Ref
  radius_literal : String
}

///|
pub fn CylindricalSurface::new(
  name : String,
  position : @step.Ref,
  radius_literal : String,
) -> CylindricalSurface {
  CylindricalSurface::{ name, position, radius_literal }
}

///|
pub impl @step.Entity for CylindricalSurface with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "CYLINDRICAL_SURFACE(\{step_str_or_dollar(self.name)},\{pos_str},\{self.radius_literal})"
}
