///|
// Represents a REPRESENTATION_CONTEXT entity.
pub struct RepresentationContext {
  context_identifier : String
  context_type : String
}

///|
pub fn RepresentationContext::new(
  context_identifier : String,
  context_type : String,
) -> RepresentationContext {
  RepresentationContext::{ context_identifier, context_type }
}

///|
pub impl @step.Entity for RepresentationContext with to_step(self) {
  "REPRESENTATION_CONTEXT(\{@step.step_str(self.context_identifier)},\{@step.step_str(self.context_type)})"
}
