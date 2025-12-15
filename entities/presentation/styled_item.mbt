///|
// Represents a STYLED_ITEM entity.
pub struct StyledItem {
  name : String
  styles : Array[@step.Ref]
  item : @step.Ref
}

///|
pub fn StyledItem::new(
  name : String,
  styles : Array[@step.Ref],
  item : @step.Ref,
) -> StyledItem {
  StyledItem::{ name, styles, item }
}

///|
pub impl @step.Entity for StyledItem with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  let item = "#\{self.item.id.value}"
  "STYLED_ITEM(\{@step.step_str(self.name)},(\{styles_str}),\{item})"
}
