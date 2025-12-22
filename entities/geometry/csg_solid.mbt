///|
// Represents a CSG_SOLID entity.
// Example:
//   CSG_SOLID('name', #10)
// where #10 is a BOOLEAN_RESULT or a CSG_PRIMITIVE.
pub struct CsgSolid {
  name : String
  tree_root_expression : @step.Ref
}

///|
pub fn CsgSolid::new(
  name : String,
  tree_root_expression : @step.Ref,
) -> CsgSolid {
  CsgSolid::{ name, tree_root_expression }
}

///|
pub impl @step.Entity for CsgSolid with to_step(self) {
  let root_str = "#\{self.tree_root_expression.id.value}"
  "CSG_SOLID(\{@step.step_str(self.name)},\{root_str})"
}
