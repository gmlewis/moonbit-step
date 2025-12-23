///|
// Represents a GEOMETRIC_TOLERANCE entity.
// Example:
//   GEOMETRIC_TOLERANCE('name', 'description', #10, #20)
// where #10 is a MEASURE_WITH_UNIT and #20 is a SHAPE_ASPECT.
pub struct GeometricTolerance {
  name : String
  description : String
  magnitude : @step.Ref
  toleranced_shape_aspect : @step.Ref
}

///|
pub fn GeometricTolerance::new(
  name : String,
  description : String,
  magnitude : @step.Ref,
  toleranced_shape_aspect : @step.Ref,
) -> GeometricTolerance {
  GeometricTolerance::{ name, description, magnitude, toleranced_shape_aspect }
}

///|
pub impl @step.Entity for GeometricTolerance with to_step(self) {
  let mag_str = "#\{self.magnitude.id.value}"
  let shape_str = "#\{self.toleranced_shape_aspect.id.value}"
  "GEOMETRIC_TOLERANCE(\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{mag_str},\{shape_str})"
}
