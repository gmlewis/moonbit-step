///|
// Represents a POSITIVE_RATIO_MEASURE value.
// This is not a standalone STEP entity row; it appears inline, e.g.
//   POSITIVE_RATIO_MEASURE(7850.)
//
// Notes:
// - We store the inner numeric literal as a raw string to preserve formatting.
pub struct PositiveRatioMeasure {
  value : String
}

///|
pub fn PositiveRatioMeasure::new(value : String) -> PositiveRatioMeasure {
  let trimmed = String::from_array(String::trim_space(value).to_array())
  PositiveRatioMeasure::{ value: trimmed }
}

///|
pub impl @step.Entity for PositiveRatioMeasure with to_step(self) {
  "POSITIVE_RATIO_MEASURE(\{self.value})"
}
