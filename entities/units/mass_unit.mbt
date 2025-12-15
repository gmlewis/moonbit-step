///|
// Represents a MASS_UNIT entity.
// Usually appears as a part of a complex unit instance alongside NAMED_UNIT and SI_UNIT.
pub struct MassUnit {}

///|
pub fn MassUnit::new() -> MassUnit {
  MassUnit::{  }
}

///|
pub impl @step.Entity for MassUnit with to_step(_) {
  "MASS_UNIT()"
}
