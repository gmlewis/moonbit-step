///|
// Represents a SHELL_BASED_SURFACE_MODEL entity.
// Example:
//   SHELL_BASED_SURFACE_MODEL('name', (#10, #20))
// where #10 and #20 are OPEN_SHELL or CLOSED_SHELL entities.
pub struct ShellBasedSurfaceModel {
  name : String
  sbsm_boundary : Array[@step.Ref]
}

///|
pub fn ShellBasedSurfaceModel::new(
  name : String,
  sbsm_boundary : Array[@step.Ref],
) -> ShellBasedSurfaceModel {
  ShellBasedSurfaceModel::{ name, sbsm_boundary }
}

///|
pub impl @step.Entity for ShellBasedSurfaceModel with to_step(self) {
  let bounds_str = self.sbsm_boundary.map(fn(r) { "#\{r.id.value}" }).join(",")
  "SHELL_BASED_SURFACE_MODEL(\{@step.step_str(self.name)},(\{bounds_str}))"
}
