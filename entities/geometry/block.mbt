///|
// Represents a BLOCK entity (CSG primitive).
// Example:
//   BLOCK('name', #10, 10.0, 20.0, 30.0)
pub struct Block {
  name : String
  position : @step.Ref
  x : Double
  y : Double
  z : Double
}

///|
pub fn Block::new(
  name : String,
  position : @step.Ref,
  x : Double,
  y : Double,
  z : Double,
) -> Block {
  Block::{ name, position, x, y, z }
}

///|
pub impl @step.Entity for Block with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "BLOCK(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.x)},\{@step.fmt_num(self.y)},\{@step.fmt_num(self.z)})"
}
