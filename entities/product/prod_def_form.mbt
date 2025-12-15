///|
// Represents a PRODUCT_DEFINITION_FORMATION entity.
// Example from MachineContactMedium.step:
//   PRODUCT_DEFINITION_FORMATION('',$,#1658)
pub struct ProductDefinitionFormation {
  id : String
  description : String
  of_product : @step.Ref
}

///|
pub fn ProductDefinitionFormation::new(
  id : String,
  description : String,
  of_product : @step.Ref,
) -> ProductDefinitionFormation {
  ProductDefinitionFormation::{ id, description, of_product }
}

///|
pub impl @step.Entity for ProductDefinitionFormation with to_step(self) {
  let product_str = "#\{self.of_product.id.value}"
  "PRODUCT_DEFINITION_FORMATION(\{step_str_or_dollar(self.id)},\{step_str_or_dollar(self.description)},\{product_str})"
}
