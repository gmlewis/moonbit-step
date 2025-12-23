///|
// Represents a DOCUMENT_REFERENCE entity.
// Example:
//   DOCUMENT_REFERENCE('id', 'name', 'description', #10)
// where #10 is a DOCUMENT.
pub struct DocumentReference {
  id : String
  name : String
  description : String
  assigned_document : @step.Ref
}

///|
pub fn DocumentReference::new(
  id : String,
  name : String,
  description : String,
  assigned_document : @step.Ref,
) -> DocumentReference {
  DocumentReference::{ id, name, description, assigned_document }
}

///|
pub impl @step.Entity for DocumentReference with to_step(self) {
  let doc_str = "#\{self.assigned_document.id.value}"
  "DOCUMENT_REFERENCE(\{@step.step_str(self.id)},\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{doc_str})"
}
