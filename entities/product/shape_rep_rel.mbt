///|
// Represents a SHAPE_REPRESENTATION_RELATIONSHIP entity.
// Example from simple-box.step:
//   SHAPE_REPRESENTATION_RELATIONSHIP('None','relationship between ...',#22,#11)
pub struct ShapeRepresentationRelationship {
  name : String
  description : String
  rep_1 : @step.Ref
  rep_2 : @step.Ref
}

///|
pub fn ShapeRepresentationRelationship::new(
  name : String,
  description : String,
  rep_1 : @step.Ref,
  rep_2 : @step.Ref,
) -> ShapeRepresentationRelationship {
  ShapeRepresentationRelationship::{ name, description, rep_1, rep_2 }
}

///|
pub impl @step.Entity for ShapeRepresentationRelationship with to_step(self) {
  let rep_1_str = "#\{self.rep_1.id.value}"
  let rep_2_str = "#\{self.rep_2.id.value}"
  "SHAPE_REPRESENTATION_RELATIONSHIP(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},\{rep_1_str},\{rep_2_str})"
}
