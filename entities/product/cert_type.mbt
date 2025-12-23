///|
// Represents a CERTIFICATION_TYPE entity.
// Example:
//   CERTIFICATION_TYPE('standard certification')
pub struct CertificationType {
  description : String
}

///|
pub fn CertificationType::new(description : String) -> CertificationType {
  CertificationType::{ description, }
}

///|
pub impl @step.Entity for CertificationType with to_step(self) {
  "CERTIFICATION_TYPE(\{@step.step_str(self.description)})"
}
