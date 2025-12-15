///|
// Represents a RECTANGULAR_TRIMMED_SURFACE entity.
// Common form:
//   RECTANGULAR_TRIMMED_SURFACE('',#<basis>,<u1>,<u2>,<v1>,<v2>,.T.,.T.)
pub struct RectangularTrimmedSurface {
  name : String
  basis_surface : @step.Ref
  u1 : String
  u2 : String
  v1 : String
  v2 : String
  usense : Bool
  vsense : Bool
}

///|
pub fn RectangularTrimmedSurface::new(
  name : String,
  basis_surface : @step.Ref,
  u1 : String,
  u2 : String,
  v1 : String,
  v2 : String,
  usense : Bool,
  vsense : Bool,
) -> RectangularTrimmedSurface {
  RectangularTrimmedSurface::{
    name,
    basis_surface,
    u1,
    u2,
    v1,
    v2,
    usense,
    vsense,
  }
}

///|
pub impl @step.Entity for RectangularTrimmedSurface with to_step(self) {
  let basis_str = "#\{self.basis_surface.id.value}"
  let usense_str = bool_to_step(self.usense)
  let vsense_str = bool_to_step(self.vsense)
  "RECTANGULAR_TRIMMED_SURFACE(\{step_str_or_dollar(self.name)},\{basis_str},\{self.u1},\{self.u2},\{self.v1},\{self.v2},\{usense_str},\{vsense_str})"
}
