///|
// Represents a SURFACE_OF_LINEAR_EXTRUSION entity.
// Example:
//   SURFACE_OF_LINEAR_EXTRUSION('name', #10, #20)
pub struct SurfaceOfLinearExtrusion {
  name : String
  swept_curve : @step.Ref
  extrusion_axis : @step.Ref
}

///|
pub fn SurfaceOfLinearExtrusion::new(
  name : String,
  swept_curve : @step.Ref,
  extrusion_axis : @step.Ref,
) -> SurfaceOfLinearExtrusion {
  SurfaceOfLinearExtrusion::{ name, swept_curve, extrusion_axis }
}

///|
pub impl @step.Entity for SurfaceOfLinearExtrusion with to_step(self) {
  let curve_str = "#\{self.swept_curve.id.value}"
  let axis_str = "#\{self.extrusion_axis.id.value}"
  "SURFACE_OF_LINEAR_EXTRUSION(\{@step.step_str(self.name)},\{curve_str},\{axis_str})"
}
