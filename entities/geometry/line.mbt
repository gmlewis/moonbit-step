///|
// Represents a LINE entity.
pub struct Line {
  name : String
  pnt : @step.Ref
  dir : @step.Ref
}

///|
pub fn Line::new(name : String, pnt : @step.Ref, dir : @step.Ref) -> Line {
  Line::{ name, pnt, dir }
}

///|
pub impl @step.Entity for Line with to_step(self) {
  let pnt = "#\{self.pnt.id.value}"
  let dir = "#\{self.dir.id.value}"
  "LINE(\{@step.step_str(self.name)},\{pnt},\{dir})"
}
