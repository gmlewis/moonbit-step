///|
// Represents a PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE entity.
// Example from simple-box.step:
//   PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE(' ',' ',#18,.NOT_KNOWN.)
pub struct ProductDefinitionFormationWithSpecifiedSource {
  id : String
  description : String
  of_product : @step.Ref
  make_or_buy : String
}

///|
pub fn ProductDefinitionFormationWithSpecifiedSource::new(
  id : String,
  description : String,
  of_product : @step.Ref,
  make_or_buy : String,
) -> ProductDefinitionFormationWithSpecifiedSource {
  ProductDefinitionFormationWithSpecifiedSource::{
    id,
    description,
    of_product,
    make_or_buy,
  }
}

///|
pub impl @step.Entity for ProductDefinitionFormationWithSpecifiedSource with to_step(
  self,
) {
  let product_str = "#\{self.of_product.id.value}"
  // make_or_buy is an enumeration like .NOT_KNOWN.
  "PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE(\{step_str_or_dollar(self.id)},\{step_str_or_dollar(self.description)},\{product_str},\{self.make_or_buy})"
}
