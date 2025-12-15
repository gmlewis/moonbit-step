///|
// Represents a SOLID_ANGLE_UNIT entity.
pub struct SolidAngleUnit {}

///|
pub fn SolidAngleUnit::new() -> SolidAngleUnit {
  SolidAngleUnit::{  }
}

///|
pub impl @step.Entity for SolidAngleUnit with to_step(_) {
  "SOLID_ANGLE_UNIT()"
}
