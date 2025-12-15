///|
// Represents a NAMED_UNIT entity (often used inside complex instances).
// In our fixtures this appears as: NAMED_UNIT(*)
pub struct NamedUnit {
  dimensions : String
}

///|
pub fn NamedUnit::new(dimensions : String) -> NamedUnit {
  NamedUnit::{ dimensions, }
}

///|
pub impl @step.Entity for NamedUnit with to_step(self) {
  "NAMED_UNIT(\{self.dimensions})"
}
