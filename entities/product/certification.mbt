///|
// Represents a CERTIFICATION entity.
// Example:
//   CERTIFICATION('name', 'purpose', #10)
// where #10 is a CERTIFICATION_TYPE.
pub struct Certification {
  name : String
  purpose : String
  kind : @step.Ref
}

///|
pub fn Certification::new(
  name : String,
  purpose : String,
  kind : @step.Ref,
) -> Certification {
  Certification::{ name, purpose, kind }
}

///|
pub impl @step.Entity for Certification with to_step(self) {
  let kind_str = "#\{self.kind.id.value}"
  "CERTIFICATION(\{@step.step_str(self.name)},\{@step.step_str(self.purpose)},\{kind_str})"
}
