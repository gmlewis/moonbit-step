///|
// Represents a PRODUCT_DEFINITION_CONTEXT entity.
// Example from simple-box.step:
//   PRODUCT_DEFINITION_CONTEXT('part definition',#21,'design')
pub struct ProductDefinitionContext {
  name : String
  application : @step.Ref
  life_cycle_stage : String
}

///|
pub fn ProductDefinitionContext::new(
  name : String,
  application : @step.Ref,
  life_cycle_stage : String,
) -> ProductDefinitionContext {
  ProductDefinitionContext::{ name, application, life_cycle_stage }
}

///|
pub impl @step.Entity for ProductDefinitionContext with to_step(self) {
  let app_str = "#\{self.application.id.value}"
  "PRODUCT_DEFINITION_CONTEXT(\{step_str_or_dollar(self.name)},\{app_str},\{step_str_or_dollar(self.life_cycle_stage)})"
}
