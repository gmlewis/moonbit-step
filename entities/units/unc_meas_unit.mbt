///|
// Represents an UNCERTAINTY_MEASURE_WITH_UNIT entity.
//
// For the simple-box fixture, the measure component is always `LENGTH_MEASURE(<literal>)`.
pub struct UncertaintyMeasureWithUnit {
  length_measure_literal : String
  unit : @step.Ref
  name : String
  description : String
}

///|
pub fn UncertaintyMeasureWithUnit::new(
  length_measure_literal : String,
  unit : @step.Ref,
  name : String,
  description : String,
) -> UncertaintyMeasureWithUnit {
  UncertaintyMeasureWithUnit::{
    length_measure_literal,
    unit,
    name,
    description,
  }
}

///|
pub impl @step.Entity for UncertaintyMeasureWithUnit with to_step(self) {
  let unit_str = "#\{self.unit.id.value}"
  "UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(\{self.length_measure_literal}),\{unit_str},\{@step.step_str(self.name)},\{@step.step_str(self.description)})"
}
