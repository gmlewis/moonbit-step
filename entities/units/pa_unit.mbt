///|
// Represents a PLANE_ANGLE_UNIT entity.
pub struct PlaneAngleUnit {}

///|
pub fn PlaneAngleUnit::new() -> PlaneAngleUnit {
  PlaneAngleUnit::{  }
}

///|
pub impl @step.Entity for PlaneAngleUnit with fn to_step(_) {
  "PLANE_ANGLE_UNIT()"
}
