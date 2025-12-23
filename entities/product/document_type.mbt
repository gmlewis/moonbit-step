///|
// Represents a DOCUMENT_TYPE entity.
// Example:
//   DOCUMENT_TYPE('configuration controlled document')
pub struct DocumentType {
  product_data_type : String
}

///|
pub fn DocumentType::new(product_data_type : String) -> DocumentType {
  DocumentType::{ product_data_type, }
}

///|
pub impl @step.Entity for DocumentType with to_step(self) {
  "DOCUMENT_TYPE(\{@step.step_str(self.product_data_type)})"
}
