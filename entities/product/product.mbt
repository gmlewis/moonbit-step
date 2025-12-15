///|
// Represents a PRODUCT entity.
// Example from simple-box.step:
//   PRODUCT('cube','cube',' ',(#19))
pub struct Product {
  name : String
  id : String
  description : String
  frame_of_reference : Array[@step.Ref]
}

///|
pub fn Product::new(
  name : String,
  id : String,
  description : String,
  frame_of_reference : Array[@step.Ref],
) -> Product {
  Product::{ name, id, description, frame_of_reference }
}

///|
pub impl @step.Entity for Product with to_step(self) {
  let refs_str = self.frame_of_reference
    .map(fn(r) { "#\{r.id.value}" })
    .join(",")
  "PRODUCT(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.id)},\{step_str_or_dollar(self.description)},(\{refs_str}))"
}
