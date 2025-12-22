///|
// Represents a HYPERBOLA entity.
// Example:
//   HYPERBOLA('name', #10, 10.0, 5.0)
pub struct Hyperbola {
  name : String
  position : @step.Ref
  semi_axis : Double
  semi_imag_axis : Double
}

///|
pub fn Hyperbola::new(
  name : String,
  position : @step.Ref,
  semi_axis : Double,
  semi_imag_axis : Double,
) -> Hyperbola {
  Hyperbola::{ name, position, semi_axis, semi_imag_axis }
}

///|
pub impl @step.Entity for Hyperbola with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "HYPERBOLA(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.semi_axis)},\{@step.fmt_num(self.semi_imag_axis)})"
}
