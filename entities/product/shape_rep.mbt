///|
// Represents a SHAPE_REPRESENTATION entity.
// Example from simple-box.step:
//   SHAPE_REPRESENTATION('cube-None',(#126),#187)
pub struct ShapeRepresentation {
  name : String
  items : Array[@step.Ref]
  context_of_items : @step.Ref
}

///|
pub fn ShapeRepresentation::new(
  name : String,
  items : Array[@step.Ref],
  context_of_items : @step.Ref,
) -> ShapeRepresentation {
  ShapeRepresentation::{ name, items, context_of_items }
}

///|
pub impl @step.Entity for ShapeRepresentation with to_step(self) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  let ctx_str = "#\{self.context_of_items.id.value}"
  "SHAPE_REPRESENTATION(\{step_str_or_dollar(self.name)},(\{items_str}),\{ctx_str})"
}
