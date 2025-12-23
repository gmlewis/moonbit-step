///|
// Represents a RIGHT_ANGULAR_WEDGE entity (CSG primitive).
// Example:
//   RIGHT_ANGULAR_WEDGE('name', #10, 10.0, 20.0, 30.0, 5.0)
pub struct RightAngularWedge {
  name : String
  position : @step.Ref
  x : Double
  y : Double
  z : Double
  ltx : Double
}

///|
pub fn RightAngularWedge::new(
  name : String,
  position : @step.Ref,
  x : Double,
  y : Double,
  z : Double,
  ltx : Double,
) -> RightAngularWedge {
  RightAngularWedge::{ name, position, x, y, z, ltx }
}

///|
pub impl @step.Entity for RightAngularWedge with to_step(self) {
  let pos_str = "#\{self.position.id.value}"
  "RIGHT_ANGULAR_WEDGE(\{@step.step_str(self.name)},\{pos_str},\{@step.fmt_num(self.x)},\{@step.fmt_num(self.y)},\{@step.fmt_num(self.z)},\{@step.fmt_num(self.ltx)})"
}
