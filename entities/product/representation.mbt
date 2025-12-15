///|
// Represents a REPRESENTATION entity.
// Example from MachineContactMedium.step:
//   REPRESENTATION('material name',(#595),#1642)
pub struct Representation {
  name : String
  items : Array[@step.Ref]
  context_of_items : @step.Ref
}

///|
pub fn Representation::new(
  name : String,
  items : Array[@step.Ref],
  context_of_items : @step.Ref,
) -> Representation {
  Representation::{ name, items, context_of_items }
}

///|
pub impl @step.Entity for Representation with to_step(self) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  let ctx_str = "#\{self.context_of_items.id.value}"
  "REPRESENTATION(\{step_str_or_dollar(self.name)},(\{items_str}),\{ctx_str})"
}
