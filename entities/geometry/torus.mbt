///|
// Represents a TORUS entity (CSG primitive).
// Note: This is the solid primitive, distinct from TOROIDAL_SURFACE.
// Example:
//   TORUS('name', #10, 20.0, 5.0)
pub struct Torus {
  name : String
  position : @step.Ref
  major_radius : Double
  minor_radius : Double
}

///|
pub fn Torus::new(
  name : String,
  position : @step.Ref,
  major_radius : Double,
  minor_radius : Double,
) -> Torus {
  Torus::{ name, position, major_radius, minor_radius }
}

///|
pub impl @step.Entity for Torus with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "TORUS(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.major_radius)},\{@step.fmt_num(self.minor_radius)})"
}
