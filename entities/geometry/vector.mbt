///|
// Represents a VECTOR entity.
pub struct Vector {
  name : String
  orientation : @step.Ref
  magnitude : Double
}

///|
pub fn Vector::new(
  name : String,
  orientation : @step.Ref,
  magnitude : Double,
) -> Vector {
  Vector::{ name, orientation, magnitude }
}

///|
pub impl @step.Entity for Vector with to_step(self) {
  let dir = "#\{self.orientation.id.value}"
  "VECTOR(\{@step.step_str(self.name)},\{dir},\{@step.fmt_num(self.magnitude)})"
}
