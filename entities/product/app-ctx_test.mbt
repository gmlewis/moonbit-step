///|
test "ApplicationContext to_step" {
  let e = @product.ApplicationContext::new(
    "core data for automotive mechanical design processes",
  )
  inspect(
    @step.Entity::to_step(e),
    content="APPLICATION_CONTEXT('core data for automotive mechanical design processes')",
  )
}
