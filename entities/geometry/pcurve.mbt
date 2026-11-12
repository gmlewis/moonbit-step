///|
// Represents a PCURVE entity: a parametric-space curve on a basis surface.
//
// Example:
//   PCURVE('',#41,#66)
pub struct PCurve {
  name : String
  basis_surface : @step.Ref
  reference_to_curve : @step.Ref
}

///|
pub fn PCurve::new(
  name : String,
  basis_surface : @step.Ref,
  reference_to_curve : @step.Ref,
) -> PCurve {
  { name, basis_surface, reference_to_curve, }
}

///|
pub impl @step.Entity for PCurve with fn to_step(self) {
  "PCURVE(\{@step.step_str(self.name)},#\{self.basis_surface.id.value},#\{self.reference_to_curve.id.value})"
}
