///|
// Represents a DEFINITIONAL_REPRESENTATION, used to wrap the 2D curve of a
// pcurve and its 2D representation context.
//
// Example:
//   DEFINITIONAL_REPRESENTATION('',(#67),#71)
pub struct DefinitionalRepresentation {
  name : String
  items : Array[@step.Ref]
  context_of_items : @step.Ref
}

///|
pub fn DefinitionalRepresentation::new(
  name : String,
  items : Array[@step.Ref],
  context_of_items : @step.Ref,
) -> DefinitionalRepresentation {
  { name, items, context_of_items, }
}

///|
pub impl @step.Entity for DefinitionalRepresentation with fn to_step(self) {
  let refs = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  "DEFINITIONAL_REPRESENTATION(\{@step.step_str(self.name)},(\{refs}),#\{self.context_of_items.id.value})"
}
