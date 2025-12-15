///|
// Represents a PRODUCT_CONTEXT entity.
// Example from simple-box.step:
//   PRODUCT_CONTEXT(' ',#21,'mechanical')
pub struct ProductContext {
  name : String
  frame_of_reference : @step.Ref
  discipline_type : String
}

///|
pub fn ProductContext::new(
  name : String,
  frame_of_reference : @step.Ref,
  discipline_type : String,
) -> ProductContext {
  ProductContext::{ name, frame_of_reference, discipline_type }
}

///|
pub impl @step.Entity for ProductContext with to_step(self) {
  let frame_str = "#\{self.frame_of_reference.id.value}"
  "PRODUCT_CONTEXT(\{step_str_or_dollar(self.name)},\{frame_str},\{step_str_or_dollar(self.discipline_type)})"
}
