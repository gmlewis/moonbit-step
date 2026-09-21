///|
test "GlobalUncertaintyAssignedContext to_step" {
  let e = @context.GlobalUncertaintyAssignedContext::new([
    @step.EntityId::{ value: 188, },
  ])
  inspect(
    @step.Entity::to_step(e),
    content="GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#188))",
  )
}

///|
test "GlobalUnitAssignedContext to_step" {
  let e = @context.GlobalUnitAssignedContext::new([
    @step.EntityId::{ value: 194, },
    @step.EntityId::{ value: 190, },
    @step.EntityId::{ value: 189, },
  ])
  inspect(
    @step.Entity::to_step(e),
    content="GLOBAL_UNIT_ASSIGNED_CONTEXT((#194,#190,#189))",
  )
}
