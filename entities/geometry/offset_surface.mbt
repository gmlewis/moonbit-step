///|
// Represents an OFFSET_SURFACE entity.
// Example:
//   OFFSET_SURFACE('name', #10, 5.0, .F.)
pub struct OffsetSurface {
  name : String
  basis_surface : @step.Ref
  distance : Double
  self_intersect : Bool
}

///|
pub fn OffsetSurface::new(
  name : String,
  basis_surface : @step.Ref,
  distance : Double,
  self_intersect : Bool,
) -> OffsetSurface {
  OffsetSurface::{ name, basis_surface, distance, self_intersect }
}

///|
pub impl @step.Entity for OffsetSurface with to_step(self) {
  let basis_str = "#\{self.basis_surface.id.value}"
  let si_str = bool_to_step(self.self_intersect)
  "OFFSET_SURFACE(\{@step.step_str(self.name)},\{basis_str},\{@step.fmt_num(self.distance)},\{si_str})"
}
