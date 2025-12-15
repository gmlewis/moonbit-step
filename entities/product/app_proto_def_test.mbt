///|
test "ApplicationProtocolDefinition to_step" {
  let e = ApplicationProtocolDefinition::new(
    "international standard",
    "automotive_design",
    2010,
    @step.Ref::{ id: @step.EntityId::{ value: 21 } },
  )
  inspect(
    @step.Entity::to_step(e),
    content="APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2010,#21)",
  )
}
