///|
// Represents a DATUM_FEATURE entity.
// Example:
//   #10=DATUM_FEATURE('name', 'description', #20, .T.)
// where #20 is a PRODUCT_DEFINITION_SHAPE.
pub struct DatumFeature {
  name : String
  description : String
  of_shape : @step.Ref
  product_definitional : String // .T., .F., .U.
}

///|
pub fn DatumFeature::new(
  name : String,
  description : String,
  of_shape : @step.Ref,
  product_definitional : String,
) -> DatumFeature {
  DatumFeature::{ name, description, of_shape, product_definitional }
}

///|
pub impl @step.Entity for DatumFeature with to_step(self) {
  let shape_str = "#\{self.of_shape.id.value}"
  "DATUM_FEATURE(\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{shape_str},\{self.product_definitional})"
}
