///|
// Represents a PLANE_ANGLE_MEASURE_WITH_UNIT entity.
//
// For the simple-box fixture, the measure component is always `PLANE_ANGLE_MEASURE(<literal>)`.
pub struct PlaneAngleMeasureWithUnit {
  plane_angle_measure_literal : String
  unit : @step.Ref
}

///|
pub fn PlaneAngleMeasureWithUnit::new(
  plane_angle_measure_literal : String,
  unit : @step.Ref,
) -> PlaneAngleMeasureWithUnit {
  PlaneAngleMeasureWithUnit::{ plane_angle_measure_literal, unit }
}

///|
pub impl @step.Entity for PlaneAngleMeasureWithUnit with to_step(self) {
  let unit_str = "#\{self.unit.id.value}"
  "PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(\{self.plane_angle_measure_literal}),\{unit_str})"
}
