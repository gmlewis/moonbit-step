///|
test "derived_unit to_step" {
  let e1 = @step.Ref::{ id: @step.EntityId::{ value: 586 } }
  let e2 = @step.Ref::{ id: @step.EntityId::{ value: 587 } }
  let entity = DerivedUnit::new([e1, e2])
  inspect(entity.to_step(), content="DERIVED_UNIT((#586,#587))")
}
