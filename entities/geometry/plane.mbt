///|
// Represents a PLANE entity.
pub struct Plane {
  name : String
  position : @step.Ref
}

///|
pub fn Plane::new(name : String, position : @step.Ref) -> Plane {
  Plane::{ name, position }
}

///|
pub impl @step.Entity for Plane with to_step(self) {
  let pos = "#\{self.position.id.value}"
  "PLANE(\{@step.step_str(self.name)},\{pos})"
}
