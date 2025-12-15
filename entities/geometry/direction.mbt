///|
// Represents a DIRECTION entity.
pub struct Direction {
  name : String
  ratios : Array[Double]
}

///|
pub fn Direction::new(name : String, ratios : Array[Double]) -> Direction {
  Direction::{ name, ratios }
}

///|
// Implement the core trait.
pub impl @step.Entity for Direction with to_step(self) {
  let ratios_str = self.ratios.map(@step.fmt_num).join(",")
  "DIRECTION(\{@step.step_str(self.name)},(\{ratios_str}))"
}
