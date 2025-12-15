///|
test "next_assembly_usage_occurrence to_step" {
  let relating = @step.Ref::{ id: @step.EntityId::{ value: 5 } }
  let related = @step.Ref::{ id: @step.EntityId::{ value: 35 } }
  let entity = NextAssemblyUsageOccurrence::new(
    "1", "R2", "$", relating, related, "$",
  )
  inspect(
    entity.to_step(),
    content="NEXT_ASSEMBLY_USAGE_OCCURRENCE('1','R2',$,#5,#35,$)",
  )
}
