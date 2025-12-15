///|
// Represents a NEXT_ASSEMBLY_USAGE_OCCURRENCE entity.
// Example from kicadoutput01-roundtrip.step:
//   NEXT_ASSEMBLY_USAGE_OCCURRENCE('1','R2',$,#5,#35,$)
pub struct NextAssemblyUsageOccurrence {
  id : String
  name : String
  description : String
  relating_product_definition : @step.Ref
  related_product_definition : @step.Ref
  reference_designator : String
}

///|
pub fn NextAssemblyUsageOccurrence::new(
  id : String,
  name : String,
  description : String,
  relating_product_definition : @step.Ref,
  related_product_definition : @step.Ref,
  reference_designator : String,
) -> NextAssemblyUsageOccurrence {
  NextAssemblyUsageOccurrence::{
    id,
    name,
    description,
    relating_product_definition,
    related_product_definition,
    reference_designator,
  }
}

///|
pub impl @step.Entity for NextAssemblyUsageOccurrence with to_step(self) {
  let relating_str = "#\{self.relating_product_definition.id.value}"
  let related_str = "#\{self.related_product_definition.id.value}"
  "NEXT_ASSEMBLY_USAGE_OCCURRENCE(\{@step.step_str(self.id)},\{@step.step_str(self.name)},\{step_str_or_dollar(self.description)},\{relating_str},\{related_str},\{step_str_or_dollar(self.reference_designator)})"
}
