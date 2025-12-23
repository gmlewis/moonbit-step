///|
// Represents an APPROVAL_STATUS entity.
// Example:
//   APPROVAL_STATUS('approved')
pub struct ApprovalStatus {
  name : String
}

///|
pub fn ApprovalStatus::new(name : String) -> ApprovalStatus {
  ApprovalStatus::{ name, }
}

///|
pub impl @step.Entity for ApprovalStatus with to_step(self) {
  "APPROVAL_STATUS(\{@step.step_str(self.name)})"
}
