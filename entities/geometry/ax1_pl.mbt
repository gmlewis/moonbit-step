///|
// Represents an AXIS1_PLACEMENT entity.
// Example:
//   AXIS1_PLACEMENT('name', #10, #20)
// where #10 is a CARTESIAN_POINT and #20 is an optional DIRECTION.
pub struct Axis1Placement {
  name : String
  location : @step.Ref
  axis : @step.Ref?
}

///|
pub fn Axis1Placement::new(
  name : String,
  location : @step.Ref,
  axis? : @step.Ref? = None,
) -> Axis1Placement {
  Axis1Placement::{ name, location, axis }
}

///|
pub impl @step.Entity for Axis1Placement with to_step(self) {
  let loc_str = "#\{self.location.id.value}"
  let axis_str = match self.axis {
    Some(r) => "#\{r.id.value}"
    None => "$"
  }
  "AXIS1_PLACEMENT(\{@step.step_str(self.name)},\{loc_str},\{axis_str})"
}
