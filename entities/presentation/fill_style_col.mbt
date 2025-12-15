///|
// Represents a FILL_AREA_STYLE_COLOUR entity.
// Note: The STEP keyword uses UK spelling (COLOUR), but internal names use US spelling.
pub struct FillAreaStyleColor {
  name : String
  color : @step.Ref
}

///|
pub fn FillAreaStyleColor::new(
  name : String,
  color : @step.Ref,
) -> FillAreaStyleColor {
  FillAreaStyleColor::{ name, color }
}

///|
pub impl @step.Entity for FillAreaStyleColor with to_step(self) {
  let c = "#\{self.color.id.value}"
  "FILL_AREA_STYLE_COLOUR(\{@step.step_str(self.name)},\{c})"
}
