///|
// Represents a SHAPE_DEFINITION_REPRESENTATION entity.
// Example from simple-box.step:
//   SHAPE_DEFINITION_REPRESENTATION(#13,#22)
pub struct ShapeDefinitionRepresentation {
  definition : @step.Ref
  used_representation : @step.Ref
}

///|
pub fn ShapeDefinitionRepresentation::new(
  definition : @step.Ref,
  used_representation : @step.Ref,
) -> ShapeDefinitionRepresentation {
  ShapeDefinitionRepresentation::{ definition, used_representation }
}

///|
pub impl @step.Entity for ShapeDefinitionRepresentation with to_step(self) {
  let def_str = "#\{self.definition.id.value}"
  let rep_str = "#\{self.used_representation.id.value}"
  "SHAPE_DEFINITION_REPRESENTATION(\{def_str},\{rep_str})"
}
