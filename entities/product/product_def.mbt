///|
// Represents a PRODUCT_DEFINITION entity.
// Example from simple-box.step:
//   PRODUCT_DEFINITION(' ','',#16,#15)
pub struct ProductDefinition {
  id : String
  description : String
  formation : @step.Ref
  frame_of_reference : @step.Ref
}

///|
pub fn ProductDefinition::new(
  id : String,
  description : String,
  formation : @step.Ref,
  frame_of_reference : @step.Ref,
) -> ProductDefinition {
  ProductDefinition::{ id, description, formation, frame_of_reference }
}

///|
pub impl @step.Entity for ProductDefinition with to_step(self) {
  let formation_str = "#\{self.formation.id.value}"
  let ctx_str = "#\{self.frame_of_reference.id.value}"
  "PRODUCT_DEFINITION(\{step_str_or_dollar(self.id)},\{step_str_or_dollar(self.description)},\{formation_str},\{ctx_str})"
}
