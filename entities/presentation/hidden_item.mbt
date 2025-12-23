///|
// Represents a HIDDEN_ELEMENT_OVER_RIDING_STYLED_ITEM entity.
// Example:
//   HIDDEN_ELEMENT_OVER_RIDING_STYLED_ITEM('name', (#10), #20, #30)
// where #10 is a style assignment, #20 is the item, and #30 is the over-ridden styled item.
pub struct HiddenElementOverRidingStyledItem {
  name : String
  styles : Array[@step.Ref]
  item : @step.Ref
  over_ridden_styled_item : @step.Ref
}

///|
pub fn HiddenElementOverRidingStyledItem::new(
  name : String,
  styles : Array[@step.Ref],
  item : @step.Ref,
  over_ridden_styled_item : @step.Ref,
) -> HiddenElementOverRidingStyledItem {
  HiddenElementOverRidingStyledItem::{
    name,
    styles,
    item,
    over_ridden_styled_item,
  }
}

///|
pub impl @step.Entity for HiddenElementOverRidingStyledItem with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  let item_str = "#\{self.item.id.value}"
  let over_str = "#\{self.over_ridden_styled_item.id.value}"
  "HIDDEN_ELEMENT_OVER_RIDING_STYLED_ITEM(\{@step.step_str(self.name)},(\{styles_str}),\{item_str},\{over_str})"
}
