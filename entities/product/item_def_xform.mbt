///|
// Represents an ITEM_DEFINED_TRANSFORMATION entity.
// Example from kicadoutput01-roundtrip.step:
//   ITEM_DEFINED_TRANSFORMATION('','',#11,#15)
pub struct ItemDefinedTransformation {
  name : String
  description : String
  transform_item_1 : @step.Ref
  transform_item_2 : @step.Ref
}

///|
pub fn ItemDefinedTransformation::new(
  name : String,
  description : String,
  transform_item_1 : @step.Ref,
  transform_item_2 : @step.Ref,
) -> ItemDefinedTransformation {
  ItemDefinedTransformation::{
    name,
    description,
    transform_item_1,
    transform_item_2,
  }
}

///|
pub impl @step.Entity for ItemDefinedTransformation with to_step(self) {
  let i1_str = "#\{self.transform_item_1.id.value}"
  let i2_str = "#\{self.transform_item_2.id.value}"
  "ITEM_DEFINED_TRANSFORMATION(\{step_str_or_dollar(self.name)},\{step_str_or_dollar(self.description)},\{i1_str},\{i2_str})"
}
