///|
test "OpenShell::to_step" {
  let faces = [
    @step.Ref::{ id: { value: 10 } },
    @step.Ref::{ id: { value: 20 } },
  ]
  let shell = OpenShell::new("test", faces)
  let s = @step.Entity::to_step(shell)
  inspect(s, content="OPEN_SHELL('test',(#10,#20))")
}
