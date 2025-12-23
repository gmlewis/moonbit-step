///|
// Represents a SWEPT_SURFACE entity.
// Example:
//   SWEPT_SURFACE('name', #10)
// where #10 is a curve.
pub struct SweptSurface {
  name : String
  swept_curve : @step.Ref
}

///|
pub fn SweptSurface::new(
  name : String,
  swept_curve : @step.Ref,
) -> SweptSurface {
  SweptSurface::{ name, swept_curve }
}

///|
pub impl @step.Entity for SweptSurface with to_step(self) {
  let curve_str = "#\{self.swept_curve.id.value}"
  "SWEPT_SURFACE(\{@step.step_str(self.name)},\{curve_str})"
}
