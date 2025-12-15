///|
// Represents a DERIVED_UNIT entity.
// Example from MachineContactMedium.step:
//   DERIVED_UNIT((#586,#587))
pub struct DerivedUnit {
  elements : Array[@step.Ref]
}

///|
pub fn DerivedUnit::new(elements : Array[@step.Ref]) -> DerivedUnit {
  DerivedUnit::{ elements, }
}

///|
pub impl @step.Entity for DerivedUnit with to_step(self) {
  let elems_str = self.elements.map(fn(r) { "#\{r.id.value}" }).join(",")
  "DERIVED_UNIT((\{elems_str}))"
}
