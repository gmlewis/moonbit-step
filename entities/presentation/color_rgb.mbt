///|
// Represents a COLOUR_RGB entity.
pub struct ColorRgb {
  name : String
  red : Double
  green : Double
  blue : Double
}

///|
pub fn ColorRgb::new(
  name : String,
  red : Double,
  green : Double,
  blue : Double,
) -> ColorRgb {
  ColorRgb::{ name, red, green, blue }
}

///|
pub impl @step.Entity for ColorRgb with to_step(self) {
  "COLOUR_RGB(\{@step.step_str(self.name)},\{@step.fmt_num(self.red)},\{@step.fmt_num(self.green)},\{@step.fmt_num(self.blue)})"
}
