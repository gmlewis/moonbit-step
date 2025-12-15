///|
// Represents a PRODUCT_RELATED_PRODUCT_CATEGORY entity.
// Example from simple-box.step:
//   PRODUCT_RELATED_PRODUCT_CATEGORY('part','',(#18))
pub struct ProductRelatedProductCategory {
  name : String
  description : String
  products : Array[@step.Ref]
}

///|
pub fn ProductRelatedProductCategory::new(
  name : String,
  description : String,
  products : Array[@step.Ref],
) -> ProductRelatedProductCategory {
  ProductRelatedProductCategory::{ name, description, products }
}

///|
pub impl @step.Entity for ProductRelatedProductCategory with to_step(self) {
  let products_str = self.products.map(fn(p) { "#\{p.id.value}" }).join(",")
  "PRODUCT_RELATED_PRODUCT_CATEGORY(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},(\{products_str}))"
}
