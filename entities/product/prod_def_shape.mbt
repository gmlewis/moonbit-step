///|
// Represents a PRODUCT_DEFINITION_SHAPE entity.
// Example from simple-box.step:
//   PRODUCT_DEFINITION_SHAPE('','',#14)
pub struct ProductDefinitionShape {
  name : String
  description : String
  definition : @step.Ref
}

///|
pub fn ProductDefinitionShape::new(
  name : String,
  description : String,
  definition : @step.Ref,
) -> ProductDefinitionShape {
  ProductDefinitionShape::{ name, description, definition }
}

///|
pub impl @step.Entity for ProductDefinitionShape with to_step(self) {
  let def_str = "#\{self.definition.id.value}"
  "PRODUCT_DEFINITION_SHAPE(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},\{def_str})"
}
