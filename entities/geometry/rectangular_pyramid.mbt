///|
// Represents a RECTANGULAR_PYRAMID entity (CSG primitive).
// Example:
//   RECTANGULAR_PYRAMID('name', #10, 10.0, 20.0, 30.0)
pub struct RectangularPyramid {
  name : String
  position : @step.Ref
  x : Double
  y : Double
  height : Double
}

///|
pub fn RectangularPyramid::new(
  name : String,
  position : @step.Ref,
  x : Double,
  y : Double,
  height : Double,
) -> RectangularPyramid {
  RectangularPyramid::{ name, position, x, y, height }
}

///|
pub impl @step.Entity for RectangularPyramid with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "RECTANGULAR_PYRAMID(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.x)},\{@step.fmt_num(self.y)},\{@step.fmt_num(self.height)})"
}
