///|
// Represents a REPRESENTATION_RELATIONSHIP entity.
//
// Example (from kicadoutput01.step complex instance part):
//   REPRESENTATION_RELATIONSHIP('','',#40,#10)
pub struct RepresentationRelationship {
  name : String
  description : String
  rep_1 : @step.Ref
  rep_2 : @step.Ref
}

///|
pub fn RepresentationRelationship::new(
  name : String,
  description : String,
  rep_1 : @step.Ref,
  rep_2 : @step.Ref,
) -> RepresentationRelationship {
  RepresentationRelationship::{ name, description, rep_1, rep_2 }
}

///|
pub impl @step.Entity for RepresentationRelationship with to_step(self) {
  let rep_1_str = "#\{self.rep_1.id.value}"
  let rep_2_str = "#\{self.rep_2.id.value}"
  "REPRESENTATION_RELATIONSHIP(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},\{rep_1_str},\{rep_2_str})"
}
