///|
// Represents a CSG_SHAPE_REPRESENTATION entity.
// Example:
//   CSG_SHAPE_REPRESENTATION('name', (#10), #20)
// where #10 is a CSG_SOLID.
pub struct CsgShapeRepresentation {
  name : String
  items : Array[@step.Ref]
  context_of_items : @step.Ref
}

///|
pub fn CsgShapeRepresentation::new(
  name : String,
  items : Array[@step.Ref],
  context_of_items : @step.Ref,
) -> CsgShapeRepresentation {
  CsgShapeRepresentation::{ name, items, context_of_items }
}

///|
pub impl @step.Entity for CsgShapeRepresentation with to_step(self) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  let ctx_str = "#\{self.context_of_items.id.value}"
  "CSG_SHAPE_REPRESENTATION(\{step_str_or_dollar(self.name)},(\{items_str}),\{ctx_str})"
}
