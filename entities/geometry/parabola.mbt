///|
// Represents a PARABOLA entity.
// Example:
//   PARABOLA('name', #10, 5.0)
pub struct Parabola {
  name : String
  position : @step.Ref
  focal_dist : Double
}

///|
pub fn Parabola::new(
  name : String,
  position : @step.Ref,
  focal_dist : Double,
) -> Parabola {
  Parabola::{ name, position, focal_dist }
}

///|
pub impl @step.Entity for Parabola with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "PARABOLA(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.focal_dist)})"
}
