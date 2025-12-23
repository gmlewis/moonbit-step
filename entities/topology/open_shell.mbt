///|
// Represents an OPEN_SHELL entity.
// Example:
//   OPEN_SHELL('name', (#10, #20))
pub struct OpenShell {
  name : String
  faces : Array[@step.Ref]
}

///|
pub fn OpenShell::new(name : String, faces : Array[@step.Ref]) -> OpenShell {
  OpenShell::{ name, faces }
}

///|
pub impl @step.Entity for OpenShell with to_step(self) {
  let faces_str = self.faces.map(fn(r) { "#\{r.id.value}" }).join(",")
  "OPEN_SHELL(\{@step.step_str(self.name)},(\{faces_str}))"
}
