///|
// Represents a SECURITY_CLASSIFICATION_LEVEL entity.
// Example:
//   SECURITY_CLASSIFICATION_LEVEL('unclassified')
pub struct SecurityClassificationLevel {
  name : String
}

///|
pub fn SecurityClassificationLevel::new(
  name : String,
) -> SecurityClassificationLevel {
  SecurityClassificationLevel::{ name, }
}

///|
pub impl @step.Entity for SecurityClassificationLevel with to_step(self) {
  "SECURITY_CLASSIFICATION_LEVEL(\{@step.step_str(self.name)})"
}
