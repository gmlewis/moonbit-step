///|
// Represents a DERIVED_UNIT_ELEMENT entity.
// Example from MachineContactMedium.step:
//   DERIVED_UNIT_ELEMENT(#588,1.)
pub struct DerivedUnitElement {
  unit : @step.Ref
  exponent : Double
}

///|
pub fn DerivedUnitElement::new(
  unit : @step.Ref,
  exponent : Double,
) -> DerivedUnitElement {
  DerivedUnitElement::{ unit, exponent }
}

///|
pub impl @step.Entity for DerivedUnitElement with to_step(self) {
  let unit_str = "#\{self.unit.id.value}"
  "DERIVED_UNIT_ELEMENT(\{unit_str},\{@step.fmt_num(self.exponent)})"
}
