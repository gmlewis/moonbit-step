///|
// Represents a SPHERE entity (CSG primitive).
// Example:
//   SPHERE('name', #10, 5.0)
pub struct Sphere {
  name : String
  position : @step.Ref
  radius : Double
}

///|
pub fn Sphere::new(
  name : String,
  position : @step.Ref,
  radius : Double,
) -> Sphere {
  Sphere::{ name, position, radius }
}

///|
pub impl @step.Entity for Sphere with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "SPHERE(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.radius)})"
}
