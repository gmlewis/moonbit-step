///|
// Represents a HALF_SPACE_SOLID entity.
// Example:
//   HALF_SPACE_SOLID('name', #10, .T.)
pub struct HalfSpaceSolid {
  name : String
  base_surface : @step.Ref
  agreement_flag : Bool
}

///|
pub fn HalfSpaceSolid::new(
  name : String,
  base_surface : @step.Ref,
  agreement_flag : Bool,
) -> HalfSpaceSolid {
  HalfSpaceSolid::{ name, base_surface, agreement_flag }
}

///|
pub impl @step.Entity for HalfSpaceSolid with to_step(self) {
  let surf_str = "#\{self.base_surface.id.value}"
  let flag_str = bool_to_step(self.agreement_flag)
  "HALF_SPACE_SOLID(\{@step.step_str(self.name)},\{surf_str},\{flag_str})"
}
