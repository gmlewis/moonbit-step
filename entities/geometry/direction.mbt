///|
// Represents a DIRECTION entity.
pub struct Direction {
  name : String
  ratios : Array[Double]
}

///|
pub fn Direction::new(name : String, ratios : Array[Double]) -> Direction {
  Direction::{ name, ratios, }
}

///|
// Implement the core trait.
pub impl @step.Entity for Direction with fn to_step(self) {
  let ratios_str = self.ratios.map(@step.fmt_num).join(",")
  "DIRECTION(\{@step.step_str(self.name)},(\{ratios_str}))"
}

///|
/// Direction::ratios_view returns the direction's direction cosines.
pub fn Direction::ratios_view(self : Direction) -> Array[Double] {
  self.ratios
}
