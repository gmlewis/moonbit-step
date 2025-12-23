///|
// Represents a SUBFACE entity.
// Example:
//   SUBFACE('name', (#10, #20), #30)
// where #10, #20 are FACE_BOUNDs and #30 is the parent FACE.
pub struct Subface {
  name : String
  bounds : Array[@step.Ref]
  parent_face : @step.Ref
}

///|
pub fn Subface::new(
  name : String,
  bounds : Array[@step.Ref],
  parent_face : @step.Ref,
) -> Subface {
  Subface::{ name, bounds, parent_face }
}

///|
pub impl @step.Entity for Subface with to_step(self) {
  let bounds_str = self.bounds.map(fn(r) { "#\{r.id.value}" }).join(",")
  let parent_str = "#\{self.parent_face.id.value}"
  "SUBFACE(\{@step.step_str(self.name)},(\{bounds_str}),\{parent_str})"
}
