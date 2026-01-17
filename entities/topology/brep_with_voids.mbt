///|
// Represents a BREP_WITH_VOIDS entity.
// Example:
//   BREP_WITH_VOIDS('', #10, (#20,#30))
// where #10 is the outer CLOSED_SHELL and #20/#30 are void CLOSED_SHELLs.
pub struct BrepWithVoids {
  name : String
  outer : @step.Ref
  voids : Array[@step.Ref]
}

///|
pub fn BrepWithVoids::new(
  name : String,
  outer : @step.Ref,
  voids : Array[@step.Ref],
) -> BrepWithVoids {
  BrepWithVoids::{ name, outer, voids }
}

///|
pub impl @step.Entity for BrepWithVoids with to_step(self) {
  let outer_str = "#\{self.outer.id.value}"
  let voids_str = self.voids.map(fn(r) { "#\{r.id.value}" }).join(",")
  "BREP_WITH_VOIDS(\{step_str_or_dollar(self.name)},\{outer_str},(\{voids_str}))"
}
