///|
test "derived_unit_element to_step" {
  let unit = @step.Ref::{ id: @step.EntityId::{ value: 588 } }
  let entity = DerivedUnitElement::new(unit, 1.0)
  inspect(entity.to_step(), content="DERIVED_UNIT_ELEMENT(#588,1.0)")
}
