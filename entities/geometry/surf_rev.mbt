///|
// Represents a SURFACE_OF_REVOLUTION entity.
// Example:
//   SURFACE_OF_REVOLUTION('name', #10, #20)
// where #10 is a swept curve and #20 is an AXIS1_PLACEMENT.
pub struct SurfaceOfRevolution {
  name : String
  swept_curve : @step.Ref
  axis_position : @step.Ref
}

///|
pub fn SurfaceOfRevolution::new(
  name : String,
  swept_curve : @step.Ref,
  axis_position : @step.Ref,
) -> SurfaceOfRevolution {
  SurfaceOfRevolution::{ name, swept_curve, axis_position }
}

///|
pub impl @step.Entity for SurfaceOfRevolution with to_step(self) {
  let curve_str = "#\{self.swept_curve.id.value}"
  let axis_str = "#\{self.axis_position.id.value}"
  "SURFACE_OF_REVOLUTION(\{@step.step_str(self.name)},\{curve_str},\{axis_str})"
}
