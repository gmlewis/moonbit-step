///|
// Represents a CONTEXT_DEPENDENT_SHAPE_REPRESENTATION entity.
// Example from kicadoutput01-roundtrip.step:
//   CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(#434,#436)
pub struct ContextDependentShapeRepresentation {
  representation_relation : @step.Ref
  represented_product_relation : @step.Ref
}

///|
pub fn ContextDependentShapeRepresentation::new(
  representation_relation : @step.Ref,
  represented_product_relation : @step.Ref,
) -> ContextDependentShapeRepresentation {
  ContextDependentShapeRepresentation::{
    representation_relation,
    represented_product_relation,
  }
}

///|
pub impl @step.Entity for ContextDependentShapeRepresentation with to_step(self) {
  let rr_str = "#\{self.representation_relation.id.value}"
  let rpr_str = "#\{self.represented_product_relation.id.value}"
  "CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(\{rr_str},\{rpr_str})"
}
