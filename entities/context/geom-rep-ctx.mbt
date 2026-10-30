///|
// Represents a GEOMETRIC_REPRESENTATION_CONTEXT entity.
pub struct GeometricRepresentationContext {
  dimension : Int32
}

///|
pub fn GeometricRepresentationContext::new(
  dimension : Int32,
) -> GeometricRepresentationContext {
  GeometricRepresentationContext::{ dimension, }
}

///|
pub impl @step.Entity for GeometricRepresentationContext with fn to_step(self) {
  "GEOMETRIC_REPRESENTATION_CONTEXT(\{self.dimension})"
}
