///|
// Represents an AXIS2_PLACEMENT_3D entity.
pub struct Axis2Placement3D {
  name : String
  location : @step.Ref
  axis : @step.Ref
  ref_direction : @step.Ref
}

///|
pub fn Axis2Placement3D::new(
  name : String,
  location : @step.Ref,
  axis : @step.Ref,
  ref_direction : @step.Ref,
) -> Axis2Placement3D {
  Axis2Placement3D::{ name, location, axis, ref_direction }
}

///|
fn ref_to_step(r : @step.Ref) -> String {
  // Access the `id` field from the @step.Ref struct
  "#\{r.id.value}"
}

///|
// Implement the core trait.
pub impl @step.Entity for Axis2Placement3D with to_step(self) {
  let loc = ref_to_step(self.location)
  let ax = ref_to_step(self.axis)
  let ref_dir = ref_to_step(self.ref_direction)
  "AXIS2_PLACEMENT_3D(\{@step.step_str(self.name)},\{loc}, \{ax}, \{ref_dir})"
}
