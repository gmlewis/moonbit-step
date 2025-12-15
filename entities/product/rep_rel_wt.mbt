///|
// Represents a REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION entity.
//
// Example (from kicadoutput01.step complex instance part):
//   REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(#435)
pub struct RepresentationRelationshipWithTransformation {
  transformation : @step.Ref
}

///|
pub fn RepresentationRelationshipWithTransformation::new(
  transformation : @step.Ref,
) -> RepresentationRelationshipWithTransformation {
  RepresentationRelationshipWithTransformation::{ transformation, }
}

///|
pub impl @step.Entity for RepresentationRelationshipWithTransformation with to_step(
  self,
) {
  let t_str = "#\{self.transformation.id.value}"
  "REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(\{t_str})"
}
