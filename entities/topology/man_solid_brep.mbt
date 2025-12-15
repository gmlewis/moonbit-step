///|
// Represents a MANIFOLD_SOLID_BREP entity.
// Example from simple-box.step:
//   MANIFOLD_SOLID_BREP('',#33)
pub struct ManifoldSolidBrep {
  name : String
  outer : @step.Ref
}

///|
pub fn ManifoldSolidBrep::new(
  name : String,
  outer : @step.Ref,
) -> ManifoldSolidBrep {
  ManifoldSolidBrep::{ name, outer }
}

///|
pub impl @step.Entity for ManifoldSolidBrep with to_step(self) {
  let outer_str = "#\{self.outer.id.value}"
  "MANIFOLD_SOLID_BREP(\{step_str_or_dollar(self.name)},\{outer_str})"
}
