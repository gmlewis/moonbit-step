///|
// Represents an ADVANCED_FACE entity.
// Example from simple-box.step:
//   ADVANCED_FACE('',(#46),#40,.F.)
pub struct AdvancedFace {
  name : String
  bounds : Array[@step.Ref]
  surface : @step.Ref
  same_sense : Bool
}

///|
pub fn AdvancedFace::new(
  name : String,
  bounds : Array[@step.Ref],
  surface : @step.Ref,
  same_sense : Bool,
) -> AdvancedFace {
  AdvancedFace::{ name, bounds, surface, same_sense }
}

///|
pub impl @step.Entity for AdvancedFace with to_step(self) {
  let bounds_str = self.bounds.map(fn(r) { "#\{r.id.value}" }).join(",")
  let surface_str = "#\{self.surface.id.value}"
  let ss_str = bool_to_step(self.same_sense)
  "ADVANCED_FACE(\{step_str_or_dollar(self.name)},(\{bounds_str}),\{surface_str},\{ss_str})"
}
