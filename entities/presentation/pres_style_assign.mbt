///|
// Represents a PRESENTATION_STYLE_ASSIGNMENT entity.
pub struct PresentationStyleAssignment {
  styles : Array[@step.Ref]
}

///|
pub fn PresentationStyleAssignment::new(
  styles : Array[@step.Ref],
) -> PresentationStyleAssignment {
  PresentationStyleAssignment::{ styles, }
}

///|
pub impl @step.Entity for PresentationStyleAssignment with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  "PRESENTATION_STYLE_ASSIGNMENT((\{styles_str}))"
}
