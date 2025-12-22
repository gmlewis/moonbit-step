///|
// Represents a RIGHT_CIRCULAR_CYLINDER entity (CSG primitive).
// Example:
//   RIGHT_CIRCULAR_CYLINDER('name', #10, 50.0, 10.0)
pub struct RightCircularCylinder {
  name : String
  position : @step.Ref
  height : Double
  radius : Double
}

///|
pub fn RightCircularCylinder::new(
  name : String,
  position : @step.Ref,
  height : Double,
  radius : Double,
) -> RightCircularCylinder {
  RightCircularCylinder::{ name, position, height, radius }
}

///|
pub impl @step.Entity for RightCircularCylinder with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "RIGHT_CIRCULAR_CYLINDER(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.height)},\{@step.fmt_num(self.radius)})"
}
