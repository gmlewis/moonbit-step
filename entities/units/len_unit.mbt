///|
// Represents a LENGTH_UNIT entity.
pub struct LengthUnit {}

///|
pub fn LengthUnit::new() -> LengthUnit {
  LengthUnit::{  }
}

///|
pub impl @step.Entity for LengthUnit with to_step(_) {
  "LENGTH_UNIT()"
}
