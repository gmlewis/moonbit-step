///|
// Represents a DATUM entity.
// Example:
//   #10=DATUM('name', 'description', #20, .T., 'A');
// where #20 is a PRODUCT_DEFINITION_SHAPE.
pub struct Datum {
  name : String
  description : String
  of_shape : @step.Ref
  product_definitional : String // .T., .F., .U.
  identification : String
}

///|
pub fn Datum::new(
  name : String,
  description : String,
  of_shape : @step.Ref,
  product_definitional : String,
  identification : String,
) -> Datum {
  Datum::{ name, description, of_shape, product_definitional, identification }
}

///|
pub impl @step.Entity for Datum with to_step(self) {
  let shape_str = "#\{self.of_shape.id.value}"
  "DATUM(\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{shape_str},\{self.product_definitional},\{@step.step_str(self.identification)})"
}
