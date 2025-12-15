///|
test "plane_angle_measure_with_unit_to_step" {
  let p = PlaneAngleMeasureWithUnit::new("0.0174532925", @step.Ref::{
    id: @step.EntityId::{ value: 193 },
  })
  inspect(
    @step.Entity::to_step(p),
    content="PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(0.0174532925),#193)",
  )
}
