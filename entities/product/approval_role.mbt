///|
// Represents an APPROVAL_ROLE entity.
// Example:
//   APPROVAL_ROLE('role')
pub struct ApprovalRole {
  role : String
}

///|
pub fn ApprovalRole::new(role : String) -> ApprovalRole {
  ApprovalRole::{ role, }
}

///|
pub impl @step.Entity for ApprovalRole with to_step(self) {
  "APPROVAL_ROLE(\{@step.step_str(self.role)})"
}
