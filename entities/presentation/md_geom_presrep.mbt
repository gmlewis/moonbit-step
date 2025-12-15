///|
// Represents a MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION entity.
// This is part of the presentation representation context in many STEP files.
pub struct MechanicalDesignGeometricPresentationRepresentation {
  name : String
  items : Array[@step.Ref]
  context : @step.Ref
}

///|
pub fn MechanicalDesignGeometricPresentationRepresentation::new(
  name : String,
  items : Array[@step.Ref],
  context : @step.Ref,
) -> MechanicalDesignGeometricPresentationRepresentation {
  MechanicalDesignGeometricPresentationRepresentation::{ name, items, context }
}

///|
pub impl @step.Entity for MechanicalDesignGeometricPresentationRepresentation with to_step(
  self,
) {
  let items_str = self.items.map(fn(r) { "#\{r.id.value}" }).join(",")
  let ctx = "#\{self.context.id.value}"
  "MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION(\{@step.step_str(self.name)},(\{items_str}),\{ctx})"
}
