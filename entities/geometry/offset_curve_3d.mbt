///|
// Represents an OFFSET_CURVE_3D entity.
// Example:
//   OFFSET_CURVE_3D('name', #10, 5.0, #20)
pub struct OffsetCurve3D {
  name : String
  basis_curve : @step.Ref
  distance : Double
  ref_direction : @step.Ref
}

///|
pub fn OffsetCurve3D::new(
  name : String,
  basis_curve : @step.Ref,
  distance : Double,
  ref_direction : @step.Ref,
) -> OffsetCurve3D {
  OffsetCurve3D::{ name, basis_curve, distance, ref_direction }
}

///|
pub impl @step.Entity for OffsetCurve3D with to_step(self) {
  let basis_str = "#\{self.basis_curve.id.value}"
  let dir_str = "#\{self.ref_direction.id.value}"
  "OFFSET_CURVE_3D(\{@step.step_str(self.name)},\{basis_str},\{@step.fmt_num(self.distance)},\{dir_str})"
}
