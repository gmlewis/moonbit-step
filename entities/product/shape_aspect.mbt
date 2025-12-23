///|
// Represents a SHAPE_ASPECT entity.
// Example:
//   SHAPE_ASPECT('name', 'description', #10, .T.)
// where #10 is a PRODUCT_DEFINITION_SHAPE.
pub struct ShapeAspect {
  name : String
  description : String
  of_shape : @step.Ref
  product_definitional : String // .T., .F., .U.
}

///|
pub fn ShapeAspect::new(
  name : String,
  description : String,
  of_shape : @step.Ref,
  product_definitional : String,
) -> ShapeAspect {
  ShapeAspect::{ name, description, of_shape, product_definitional }
}

///|
pub impl @step.Entity for ShapeAspect with to_step(self) {
  let shape_str = "#\{self.of_shape.id.value}"
  "SHAPE_ASPECT(\{@step.step_str(self.name)},\{@step.step_str(self.description)},\{shape_str},\{self.product_definitional})"
}
