///|
// Represents a FILL_AREA_STYLE entity.
pub struct FillAreaStyle {
  name : String
  styles : Array[@step.Ref]
}

///|
pub fn FillAreaStyle::new(
  name : String,
  styles : Array[@step.Ref],
) -> FillAreaStyle {
  FillAreaStyle::{ name, styles }
}

///|
pub impl @step.Entity for FillAreaStyle with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  "FILL_AREA_STYLE(\{@step.step_str(self.name)},(\{styles_str}))"
}
