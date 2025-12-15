///|
// Represents a CLOSED_SHELL entity.
// Example from simple-box.step:
//   CLOSED_SHELL('',(#34,#35,#36,#37,#38,#39))
pub struct ClosedShell {
  name : String
  faces : Array[@step.Ref]
}

///|
pub fn ClosedShell::new(name : String, faces : Array[@step.Ref]) -> ClosedShell {
  ClosedShell::{ name, faces }
}

///|
pub impl @step.Entity for ClosedShell with to_step(self) {
  let faces_str = self.faces.map(fn(r) { "#\{r.id.value}" }).join(",")
  "CLOSED_SHELL(\{step_str_or_dollar(self.name)},(\{faces_str}))"
}
