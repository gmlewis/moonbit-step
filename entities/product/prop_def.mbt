///|
// Represents a PROPERTY_DEFINITION entity.
// Example from MachineContactMedium.step:
//   PROPERTY_DEFINITION('material property','material name',#1652)
pub struct PropertyDefinition {
  name : String
  description : String
  definition : @step.Ref
}

///|
pub fn PropertyDefinition::new(
  name : String,
  description : String,
  definition : @step.Ref,
) -> PropertyDefinition {
  PropertyDefinition::{ name, description, definition }
}

///|
pub impl @step.Entity for PropertyDefinition with to_step(self) {
  let def_str = "#\{self.definition.id.value}"
  "PROPERTY_DEFINITION(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},\{def_str})"
}
