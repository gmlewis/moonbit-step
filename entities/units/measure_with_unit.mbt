///|
// Represents a MEASURE_WITH_UNIT entity.
// Example:
//   MEASURE_WITH_UNIT(LENGTH_MEASURE(5.0), #10)
pub struct MeasureWithUnit {
  value_component : String // e.g. "LENGTH_MEASURE(5.0)"
  unit_component : @step.Ref
}

///|
pub fn MeasureWithUnit::new(
  value_component : String,
  unit_component : @step.Ref,
) -> MeasureWithUnit {
  MeasureWithUnit::{ value_component, unit_component }
}

///|
pub impl @step.Entity for MeasureWithUnit with to_step(self) {
  let unit_str = "#\{self.unit_component.id.value}"
  "MEASURE_WITH_UNIT(\{self.value_component},\{unit_str})"
}
