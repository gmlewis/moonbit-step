///|
test "ShellBasedSurfaceModel::to_step" {
  let bounds = [
    @step.Ref::{ id: { value: 10 } },
    @step.Ref::{ id: { value: 20 } },
  ]
  let model = ShellBasedSurfaceModel::new("test", bounds)
  let s = @step.Entity::to_step(model)
  inspect(s, content="SHELL_BASED_SURFACE_MODEL('test',(#10,#20))")
}
