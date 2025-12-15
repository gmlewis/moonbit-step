///|
// Represents a GEOMETRIC_REPRESENTATION_CONTEXT entity.
pub struct GeometricRepresentationContext {
  dimension : Int
}

///|
pub fn GeometricRepresentationContext::new(
  dimension : Int,
) -> GeometricRepresentationContext {
  GeometricRepresentationContext::{ dimension, }
}

///|
pub impl @step.Entity for GeometricRepresentationContext with to_step(self) {
  "GEOMETRIC_REPRESENTATION_CONTEXT(\{self.dimension})"
}
