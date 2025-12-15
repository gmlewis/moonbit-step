///|
// Represents a PROPERTY_DEFINITION_REPRESENTATION entity.
// Example from MachineContactMedium.step:
//   PROPERTY_DEFINITION_REPRESENTATION(#596,#593)
pub struct PropertyDefinitionRepresentation {
  definition : @step.Ref
  used_representation : @step.Ref
}

///|
pub fn PropertyDefinitionRepresentation::new(
  definition : @step.Ref,
  used_representation : @step.Ref,
) -> PropertyDefinitionRepresentation {
  PropertyDefinitionRepresentation::{ definition, used_representation }
}

///|
pub impl @step.Entity for PropertyDefinitionRepresentation with to_step(self) {
  let def_str = "#\{self.definition.id.value}"
  let rep_str = "#\{self.used_representation.id.value}"
  "PROPERTY_DEFINITION_REPRESENTATION(\{def_str},\{rep_str})"
}
