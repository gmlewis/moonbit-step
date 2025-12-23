///|
test "Approval::to_step" {
  let status = @step.Ref::{ id: { value: 10 } }
  let approval = Approval::new(status, "level")
  let s = @step.Entity::to_step(approval)
  inspect(s, content="APPROVAL(#10,'level')")
}
