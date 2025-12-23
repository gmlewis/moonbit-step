///|
// Represents a text_path enumeration in STEP.
pub(all) enum TextPath {
  Left
  Right
  Up
  Down
}

///|
pub impl @step.Entity for TextPath with to_step(self) {
  match self {
    Left => ".LEFT."
    Right => ".RIGHT."
    Up => ".UP."
    Down => ".DOWN."
  }
}

///|
pub fn TextPath::from_string(s : String) -> TextPath? {
  match s {
    ".LEFT." => Some(Left)
    ".RIGHT." => Some(Right)
    ".UP." => Some(Up)
    ".DOWN." => Some(Down)
    _ => None
  }
}

///|
// Represents a TEXT_LITERAL entity.
// Example:
//   TEXT_LITERAL('name', 'literal', #10, 'alignment', .RIGHT., #20)
pub struct TextLiteral {
  name : String
  literal : String
  placement : @step.Ref
  alignment : String
  path : TextPath
  font : @step.Ref
}

///|
pub fn TextLiteral::new(
  name : String,
  literal : String,
  placement : @step.Ref,
  alignment : String,
  path : TextPath,
  font : @step.Ref,
) -> TextLiteral {
  TextLiteral::{ name, literal, placement, alignment, path, font }
}

///|
pub impl @step.Entity for TextLiteral with to_step(self) {
  let placement_str = "#\{self.placement.id.value}"
  let path_str = @step.Entity::to_step(self.path)
  let font_str = "#\{self.font.id.value}"
  "TEXT_LITERAL(\{@step.step_str(self.name)},\{@step.step_str(self.literal)},\{placement_str},\{@step.step_str(self.alignment)},\{path_str},\{font_str})"
}
