///|
test "ClosedShell to_step" {
  let e = ClosedShell::new("", [
    @step.Ref::{ id: @step.EntityId::{ value: 34 } },
    @step.Ref::{ id: @step.EntityId::{ value: 35 } },
    @step.Ref::{ id: @step.EntityId::{ value: 36 } },
    @step.Ref::{ id: @step.EntityId::{ value: 37 } },
    @step.Ref::{ id: @step.EntityId::{ value: 38 } },
    @step.Ref::{ id: @step.EntityId::{ value: 39 } },
  ])
  inspect(
    @step.Entity::to_step(e),
    content="CLOSED_SHELL('',(#34,#35,#36,#37,#38,#39))",
  )
}
