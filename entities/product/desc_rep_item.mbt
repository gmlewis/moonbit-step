///|
// Represents a DESCRIPTIVE_REPRESENTATION_ITEM entity.
// Example from MachineContactMedium.step:
//   DESCRIPTIVE_REPRESENTATION_ITEM('Steel','Steel')
pub struct DescriptiveRepresentationItem {
  name : String
  description : String
}

///|
pub fn DescriptiveRepresentationItem::new(
  name : String,
  description : String,
) -> DescriptiveRepresentationItem {
  DescriptiveRepresentationItem::{ name, description }
}

///|
pub impl @step.Entity for DescriptiveRepresentationItem with to_step(self) {
  "DESCRIPTIVE_REPRESENTATION_ITEM(\{@step.step_str(self.name)},\{@step.step_str(self.description)})"
}
