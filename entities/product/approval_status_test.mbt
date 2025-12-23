///|
test "ApprovalStatus::to_step" {
  let status = ApprovalStatus::new("approved")
  let s = @step.Entity::to_step(status)
  inspect(s, content="APPROVAL_STATUS('approved')")
}
