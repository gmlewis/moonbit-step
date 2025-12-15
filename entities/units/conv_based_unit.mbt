///|
// Represents a CONVERSION_BASED_UNIT entity.
// Example from simple-box.step:
//   CONVERSION_BASED_UNIT('DEGREE',#192)
pub struct ConversionBasedUnit {
  name : String
  conversion_factor : @step.Ref
}

///|
pub fn ConversionBasedUnit::new(
  name : String,
  conversion_factor : @step.Ref,
) -> ConversionBasedUnit {
  ConversionBasedUnit::{ name, conversion_factor }
}

///|
pub impl @step.Entity for ConversionBasedUnit with to_step(self) {
  let factor_str = "#\{self.conversion_factor.id.value}"
  "CONVERSION_BASED_UNIT(\{@step.step_str(self.name)},\{factor_str})"
}
