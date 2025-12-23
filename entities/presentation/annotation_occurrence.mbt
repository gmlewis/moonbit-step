///|
// Represents an ANNOTATION_OCCURRENCE entity.
// Example:
//   ANNOTATION_OCCURRENCE('name', (#10), #20)
// where #10 is a style assignment and #20 is the item.
pub struct AnnotationOccurrence {
  name : String
  styles : Array[@step.Ref]
  item : @step.Ref
}

///|
pub fn AnnotationOccurrence::new(
  name : String,
  styles : Array[@step.Ref],
  item : @step.Ref,
) -> AnnotationOccurrence {
  AnnotationOccurrence::{ name, styles, item }
}

///|
pub impl @step.Entity for AnnotationOccurrence with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  let item_str = "#\{self.item.id.value}"
  "ANNOTATION_OCCURRENCE(\{@step.step_str(self.name)},(\{styles_str}),\{item_str})"
}
