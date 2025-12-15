///|
// Represents a PRESENTATION_LAYER_ASSIGNMENT entity.
// Items are generic references (often to geometry/topology entities).
pub struct PresentationLayerAssignment {
  name : String
  description : String
  items : Array[@step.Ref]
}

///|
pub fn PresentationLayerAssignment::new(
  name : String,
  description : String,
  items : Array[@step.Ref],
) -> PresentationLayerAssignment {
  PresentationLayerAssignment::{ name, description, items }
}

///|
pub impl @step.Entity for PresentationLayerAssignment with to_step(self) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  "PRESENTATION_LAYER_ASSIGNMENT(\{@step.step_str(self.name)},\{@step.step_str(self.description)},(\{items_str}))"
}
