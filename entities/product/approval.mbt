///|
// Represents an APPROVAL entity.
// Example:
//   APPROVAL(#10, 'level')
// where #10 is an APPROVAL_STATUS.
pub struct Approval {
  status : @step.Ref
  level : String
}

///|
pub fn Approval::new(status : @step.Ref, level : String) -> Approval {
  Approval::{ status, level }
}

///|
pub impl @step.Entity for Approval with to_step(self) {
  let status_str = "#\{self.status.id.value}"
  "APPROVAL(\{status_str},\{@step.step_str(self.level)})"
}
