///|
test "uncertainty_measure_with_unit_to_step" {
  let u = UncertaintyMeasureWithUnit::new(
    "2.E-005",
    @step.Ref::{ id: @step.EntityId::{ value: 194 } },
    "DISTANCE_ACCURACY_VALUE",
    "Maximum Tolerance applied to model",
  )
  inspect(
    @step.Entity::to_step(u),
    content="UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(2.E-005),#194,'DISTANCE_ACCURACY_VALUE','Maximum Tolerance applied to model')",
  )
}
