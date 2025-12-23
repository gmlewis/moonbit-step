///|
// Represents a DIMENSIONAL_SIZE entity.
// Example:
//   #10=DIMENSIONAL_SIZE(#20, 'name');
// where #20 is a SHAPE_ASPECT.
pub struct DimensionalSize {
  applies_to : @step.Ref
  name : String
}

///|
pub fn DimensionalSize::new(
  applies_to : @step.Ref,
  name : String,
) -> DimensionalSize {
  DimensionalSize::{ applies_to, name }
}

///|
pub impl @step.Entity for DimensionalSize with to_step(self) {
  let applies_to_str = "#\{self.applies_to.id.value}"
  "DIMENSIONAL_SIZE(\{applies_to_str},\{@step.step_str(self.name)})"
}
