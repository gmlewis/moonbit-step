///|
// Represents a DOCUMENT entity.
// Example:
//   DOCUMENT('id', 'name', 'description', #10)
// where #10 is a DOCUMENT_TYPE.
pub struct Document {
  id : String
  name : String
  description : String
  kind : @step.Ref
}

///|
pub fn Document::new(
  id : String,
  name : String,
  description : String,
  kind : @step.Ref,
) -> Document {
  Document::{ id, name, description, kind }
}

///|
pub impl @step.Entity for Document with to_step(self) {
  let kind_str = "#\{self.kind.id.value}"
  "DOCUMENT(\{@step.step_str(self.id)},\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{kind_str})"
}
