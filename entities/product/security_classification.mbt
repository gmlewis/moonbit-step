///|
// Represents a SECURITY_CLASSIFICATION entity.
// Example:
//   SECURITY_CLASSIFICATION('name', 'purpose', #10)
// where #10 is a SECURITY_CLASSIFICATION_LEVEL.
pub struct SecurityClassification {
  name : String
  purpose : String
  security_level : @step.Ref
}

///|
pub fn SecurityClassification::new(
  name : String,
  purpose : String,
  security_level : @step.Ref,
) -> SecurityClassification {
  SecurityClassification::{ name, purpose, security_level }
}

///|
pub impl @step.Entity for SecurityClassification with to_step(self) {
  let level_str = "#\{self.security_level.id.value}"
  "SECURITY_CLASSIFICATION(\{@step.step_str(self.name)},\{@step.step_str(self.purpose)},\{level_str})"
}
