///|
// Represents a RIGHT_CIRCULAR_CONE entity (CSG primitive).
// Example:
//   RIGHT_CIRCULAR_CONE('name', #10, 50.0, 10.0, 0.5)
pub struct RightCircularCone {
  name : String
  position : @step.Ref
  height : Double
  radius : Double
  semi_angle : Double
}

///|
pub fn RightCircularCone::new(
  name : String,
  position : @step.Ref,
  height : Double,
  radius : Double,
  semi_angle : Double,
) -> RightCircularCone {
  RightCircularCone::{ name, position, height, radius, semi_angle }
}

///|
pub impl @step.Entity for RightCircularCone with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "RIGHT_CIRCULAR_CONE(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.height)},\{@step.fmt_num(self.radius)},\{@step.fmt_num(self.semi_angle)})"
}
