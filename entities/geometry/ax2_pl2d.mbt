///|
// Represents an AXIS2_PLACEMENT_2D entity.
// Example:
//   AXIS2_PLACEMENT_2D('name', #10, #20)
// where #10 is a CARTESIAN_POINT and #20 is an optional DIRECTION.
pub struct Axis2Placement2D {
  name : String
  location : @step.Ref
  ref_direction : @step.Ref?
}

///|
pub fn Axis2Placement2D::new(
  name : String,
  location : @step.Ref,
  ref_direction? : @step.Ref? = None,
) -> Axis2Placement2D {
  Axis2Placement2D::{ name, location, ref_direction }
}

///|
pub impl @step.Entity for Axis2Placement2D with to_step(self) {
  let loc_str = "#\{self.location.id.value}"
  let dir_str = match self.ref_direction {
    Some(r) => "#\{r.id.value}"
    None => "$"
  }
  "AXIS2_PLACEMENT_2D(\{@step.step_str(self.name)},\{loc_str},\{dir_str})"
}
