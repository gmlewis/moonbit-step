///|
test "MeasureWithUnit::to_step" {
  let unit = @step.Ref::{ id: { value: 10, }, }
  let m = @units.MeasureWithUnit::new("LENGTH_MEASURE(5.0)", unit)
  inspect(
    @step.Entity::to_step(m),
    content="MEASURE_WITH_UNIT(LENGTH_MEASURE(5.0),#10)",
  )
}
