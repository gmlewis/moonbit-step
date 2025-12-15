///|
// Represents an ADVANCED_BREP_SHAPE_REPRESENTATION entity.
// Example from simple-box.step:
//   ADVANCED_BREP_SHAPE_REPRESENTATION('cube-None',(#32),#187)
pub struct AdvancedBrepShapeRepresentation {
  name : String
  items : Array[@step.Ref]
  context_of_items : @step.Ref
}

///|
pub fn AdvancedBrepShapeRepresentation::new(
  name : String,
  items : Array[@step.Ref],
  context_of_items : @step.Ref,
) -> AdvancedBrepShapeRepresentation {
  AdvancedBrepShapeRepresentation::{ name, items, context_of_items }
}

///|
pub impl @step.Entity for AdvancedBrepShapeRepresentation with to_step(self) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  let ctx_str = "#\{self.context_of_items.id.value}"
  "ADVANCED_BREP_SHAPE_REPRESENTATION(\{@step.step_str(self.name)},(\{items_str}),\{ctx_str})"
}
